package r2

import (
	"crypto/sha256"
	"encoding/hex"
	"iter"

	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/io"
	"github.com/alexfalkowski/go-service/v3/net/http"
	"github.com/alexfalkowski/go-service/v3/os"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/termermc/go-micro-s3/client"
	"github.com/termermc/go-micro-s3/client/api"
)

// NewStore resolves the configured credentials and constructs a Store.
func NewStore(cfg *Config, fs *os.FS) (*Store, error) {
	accessKeyID, err := cfg.GetAccessKeyID(fs)
	if err != nil {
		return nil, err
	}
	secretAccessKey, err := cfg.GetSecretAccessKey(fs)
	if err != nil {
		return nil, err
	}

	transport := http.Transport(nil)
	filter := http.ClosingRoundTripper(func(req *http.Request) (*http.Response, error, bool) {
		// The client adds the conditional header to every multipart operation.
		// R2 documents it on initiation and completion, and SigV4 leaves it unsigned.
		if req.Method != http.MethodPost && req.URL.Query().Has("uploadId") {
			req = req.Clone(req.Context())
			req.Header.Del("If-None-Match")
		}

		res, err := transport.RoundTrip(req)
		return res, err, false
	})
	httpClient := http.NewClient(filter, cfg.RequestTimeout)
	httpClient.CheckRedirect = http.IgnoreRedirect

	s3, err := client.New(client.Config{
		Endpoint:        cfg.Endpoint.String(),
		Region:          cfg.Region,
		AccessKeyId:     accessKeyID,
		SecretAccessKey: secretAccessKey,
		HttpClient:      httpClient,
	})
	if err != nil {
		return nil, err
	}

	return &Store{client: s3, bucket: cfg.Bucket}, nil
}

// Store transfers and verifies objects in the configured R2 bucket.
type Store struct {
	client *client.Client
	bucket string
}

// List yields object keys with the given prefix and stops on the first error.
func (s *Store) List(ctx context.Context, prefix string) iter.Seq2[string, error] {
	return func(yield func(string, error) bool) {
		for entry, err := range s.client.List(ctx, s.bucket, &client.ListOptions{Prefix: prefix}) {
			if err != nil {
				yield(strings.Empty, err)
				return
			}
			if err := ctx.Err(); err != nil {
				yield(strings.Empty, err)
				return
			}
			if !yield(entry.Key, nil) {
				return
			}
		}
	}
}

// URI returns the S3 URI for an object key.
func (s *Store) URI(key string) string {
	return strings.Concat("s3://", s.bucket, "/", key)
}

// CheckPublication verifies that the stored bytes match the published checksum.
func (s *Store) CheckPublication(ctx context.Context, key, checksum string) error {
	meta, err := s.client.Stat(ctx, s.bucket, key, nil)
	if err != nil {
		return err
	}
	if meta.Metadata["sha256"] != checksum {
		return errors.New("remote log archive no longer matches confirmed publication")
	}
	_, err = s.verifyChecksum(ctx, key, meta)
	return err
}

// Create streams an object and its checksum with a condition that the key is absent.
func (s *Store) Create(ctx context.Context, key, checksum string, file io.Reader, size int64) error {
	_, err := s.client.Upload(ctx, s.bucket, key, file, size, &client.UploadOptions{
		Metadata:     api.ObjectCustomMetadata{"sha256": checksum},
		ExtraHeaders: http.Header{"If-None-Match": {"*"}},
	})
	return err
}

// Checksum verifies the object's bytes against its SHA-256 metadata.
// It returns an empty checksum when the object is absent.
func (s *Store) Checksum(ctx context.Context, key string) (string, error) {
	meta, err := s.client.Stat(ctx, s.bucket, key, nil)
	if api.IsNotFound(err) {
		return strings.Empty, nil
	}
	if err != nil {
		return strings.Empty, err
	}
	return s.verifyChecksum(ctx, key, meta)
}

func (s *Store) verifyChecksum(ctx context.Context, key string, meta client.ObjectInfo) (string, error) {
	checksum := meta.Metadata["sha256"]
	if strings.IsEmpty(checksum) || strings.IsEmpty(meta.ETag) {
		return strings.Empty, errors.New("remote log archive is missing checksum metadata or ETag")
	}

	object, err := s.client.Api().GetObject(ctx, &api.GetObjectInput{
		Bucket:       s.bucket,
		Key:          key,
		ExtraHeaders: http.Header{"If-Match": {meta.ETag}},
	})
	if err != nil {
		return strings.Empty, err
	}
	defer object.Body.Close()

	hash := sha256.New()
	size, err := io.Copy(hash, object.Body)
	if err != nil {
		return strings.Empty, err
	}
	if size != meta.Size || hex.EncodeToString(hash.Sum(nil)) != checksum {
		return strings.Empty, errors.New("remote log archive checksum verification failed")
	}
	return checksum, nil
}
