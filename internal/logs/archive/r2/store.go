package r2

import (
	"crypto/sha256"
	"encoding/hex"

	"github.com/alexfalkowski/einblick/internal/logs/archive"
	"github.com/alexfalkowski/go-service/v3/bytes"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/io"
	"github.com/alexfalkowski/go-service/v3/net/http"
	"github.com/alexfalkowski/go-service/v3/os"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/termermc/go-micro-s3/client"
	"github.com/termermc/go-micro-s3/client/api"
)

// NewStore constructs an R2 adapter without contacting the bucket.
// A missing R2 configuration leaves publication disabled.
func NewStore(cfg *Config, fs *os.FS) (archive.ObjectStore, error) {
	if cfg == nil {
		return nil, nil //nolint:nilnil // Publication is optional.
	}

	accessKeyID, err := fs.ReadSource(cfg.AccessKeyID)
	if err != nil {
		return nil, errors.Prefix("R2 access key ID", err)
	}

	secretAccessKey, err := fs.ReadSource(cfg.SecretAccessKey)
	if err != nil {
		return nil, errors.Prefix("R2 secret access key", err)
	}

	if len(accessKeyID) == 0 || len(secretAccessKey) == 0 {
		return nil, errors.New("R2 credential sources must not be empty")
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
		AccessKeyId:     bytes.String(accessKeyID),
		SecretAccessKey: bytes.String(secretAccessKey),
		HttpClient:      httpClient,
	})
	if err != nil {
		return nil, err
	}
	return &store{client: s3, bucket: cfg.Bucket}, nil
}

type store struct {
	client *client.Client
	bucket string
}

func (s *store) Create(ctx context.Context, key, checksum string, file io.Reader, size int64) error {
	_, err := s.client.Upload(ctx, s.bucket, key, file, size, &client.UploadOptions{
		Metadata:     api.ObjectCustomMetadata{"sha256": checksum},
		ExtraHeaders: http.Header{"If-None-Match": {"*"}},
	})
	return err
}

func (s *store) Checksum(ctx context.Context, key string) (string, error) {
	meta, err := s.client.Stat(ctx, s.bucket, key, nil)
	if api.IsNotFound(err) {
		return strings.Empty, nil
	}
	if err != nil {
		return strings.Empty, err
	}

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
