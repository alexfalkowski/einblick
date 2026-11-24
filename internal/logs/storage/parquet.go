package storage

import (
	"bufio"
	"os"

	"github.com/alexfalkowski/einblick/internal/logs/archive"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/apache/arrow-go/v18/arrow"
	"github.com/apache/arrow-go/v18/arrow/array"
	"github.com/apache/arrow-go/v18/arrow/memory"
	"github.com/apache/arrow-go/v18/parquet"
	"github.com/apache/arrow-go/v18/parquet/compress"
	"github.com/apache/arrow-go/v18/parquet/pqarrow"
)

const parquetFileMode = 0o600

// WriteParquet writes the immutable batch to path in log ID order. It reads
// the result back through DuckDB to verify its contents before returning.
func (r *Archive) WriteParquet(ctx context.Context, batch archive.Batch, path string) error {
	if err := r.writeParquetFile(ctx, batch.ID, path); err != nil {
		return errors.Prefix("write archive Parquet", err)
	}

	digest, err := r.parquetContentDigest(ctx, path)
	if err != nil {
		return err
	}
	if digest != batch.ContentDigest {
		return errors.New("log archive Parquet contents differ from batch")
	}

	return nil
}

func (r *Archive) writeParquetFile(ctx context.Context, key, path string) (err error) {
	file, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, parquetFileMode)
	if err != nil {
		return err
	}
	defer func() { err = errors.Join(err, file.Close()) }()

	schema := arrow.NewSchema([]arrow.Field{
		{Name: "log_id", Type: arrow.PrimitiveTypes.Int64},
		{Name: "timestamp_ns", Type: arrow.PrimitiveTypes.Uint64},
		{Name: "observed_timestamp_ns", Type: arrow.PrimitiveTypes.Uint64},
		{Name: "received_timestamp_ns", Type: arrow.PrimitiveTypes.Uint64},
		{Name: "event_timestamp_ns", Type: arrow.PrimitiveTypes.Uint64},
		{Name: "resource", Type: arrow.BinaryTypes.String},
		{Name: "scope", Type: arrow.BinaryTypes.String},
		{Name: "record", Type: arrow.BinaryTypes.String},
	}, nil)
	properties := parquet.NewWriterProperties(parquet.WithCompression(compress.Codecs.Zstd))
	// Arrow panics if writing the header fails. Buffer it so filesystem
	// failures are returned by a row group write or the final flush.
	output := bufio.NewWriter(file)
	writer, err := pqarrow.NewFileWriter(schema, output, properties, pqarrow.DefaultWriterProps())
	if err != nil {
		return err
	}
	defer func() { err = errors.Join(err, writer.Close(), output.Flush()) }()

	builder := array.NewRecordBuilder(memory.DefaultAllocator, schema)
	defer builder.Release()

	var groupBytes int64
	flush := func() error {
		group := builder.NewRecordBatch()
		defer group.Release()
		groupBytes = 0
		return writer.Write(group)
	}

	err = r.visitArchiveRows(ctx, key, func(row [8]string) error {
		// Use the Parquet page size as the uncompressed row group target.
		// A record wider than the target still gets a group of its own.
		rowBytes := int64(5*8 + len(row[5]) + len(row[6]) + len(row[7]))
		if groupBytes > 0 && groupBytes+rowBytes > parquet.DefaultDataPageSize {
			if err := flush(); err != nil {
				return err
			}
		}
		for i, value := range row {
			if err := builder.Field(i).AppendValueFromString(value); err != nil {
				return err
			}
		}
		groupBytes += rowBytes
		return nil
	})
	if err != nil || groupBytes == 0 {
		return err
	}
	return flush()
}
