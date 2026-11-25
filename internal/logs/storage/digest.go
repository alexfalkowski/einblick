package storage

import (
	"cmp"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"hash"

	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/database/sql"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/slices"
	"github.com/alexfalkowski/go-service/v3/strings"
)

const (
	// Retain the former export byte target for a checksum read. One accepted
	// record can exceed it, so each page includes at least its first row.
	digestPageBytes = 65_536
	// Bound the rows scanned for sizes before projecting their contents.
	digestPageRows = 128
)

type digestRow struct {
	fields   [8]string
	position int64
}

type digestRowSize struct {
	position int64
	bytes    int64
}

func newArchiveDigest() hash.Hash {
	digest := sha256.New()
	_, _ = digest.Write([]byte("einblick/logs/v1\x00"))
	return digest
}

func (r *Archive) sourceDigest(ctx context.Context, key string) (string, error) {
	digest := newArchiveDigest()
	err := r.visitArchiveRows(ctx, key, func(row [8]string) error {
		hashArchiveRow(digest, row)
		return nil
	})
	if err != nil {
		return strings.Empty, err
	}
	return hex.EncodeToString(digest.Sum(nil)), nil
}

func (r *Archive) visitArchiveRows(ctx context.Context, key string, visit func([8]string) error) error {
	read, err := r.db.PrepareContext(ctx, sourceRowsQuery)
	if err != nil {
		return err
	}
	defer read.Close()

	var position int64
	for {
		rows, err := r.db.QueryContext(ctx, sourcePositionQuery, key, position, digestPageRows)
		if err != nil {
			return errors.Prefix("select archive row positions", err)
		}
		positions, err := readDigestPositions(rows)
		if err != nil {
			return err
		}
		if len(positions) == 0 {
			return nil
		}

		// Point reads use the log ID index. DuckDB can allocate an entire
		// string vector during a range scan before it applies the row filter.
		for _, position := range positions {
			var row [8]string
			err := read.QueryRowContext(ctx, key, position).Scan(&row[0], &row[1], &row[2], &row[3],
				&row[4], &row[5], &row[6], &row[7])
			if err != nil {
				return errors.Prefix("read source archive row", err)
			}
			if err := visit(row); err != nil {
				return err
			}
		}
		position = positions[len(positions)-1]
	}
}

func readDigestPositions(rows *sql.Rows) ([]int64, error) {
	defer rows.Close()

	positions := make([]int64, 0, digestPageRows)
	for rows.Next() {
		var position int64
		if err := rows.Scan(&position); err != nil {
			return nil, err
		}
		positions = append(positions, position)
	}
	return positions, rows.Err()
}

func (r *Archive) parquetContentDigest(ctx context.Context, path string) (string, error) {
	var count int64
	if err := r.db.QueryRowContext(ctx, parquetCountQuery, path).Scan(&count); err != nil {
		return strings.Empty, err
	}

	pageSizes := strings.Concat(parquetRowsQuery, digestPageSizesQuery)
	page := strings.Concat(parquetRowsQuery, digestPageQuery)
	digest := newArchiveDigest()
	for start := int64(0); start < count; {
		end := start + min(digestPageRows, count-start) - 1
		sizes, err := r.db.QueryContext(ctx, pageSizes, path, start, end)
		if err != nil {
			return strings.Empty, errors.Prefix("size archive digest page", err)
		}
		ends, err := digestSpanEnds(sizes)
		if err != nil {
			return strings.Empty, err
		}
		for _, end := range ends {
			rows, err := r.db.QueryContext(ctx, page, path, start, end)
			if err != nil {
				return strings.Empty, errors.Prefix("read archive digest page", err)
			}
			if err := hashArchivePage(rows, digest); err != nil {
				return strings.Empty, err
			}
			start = end + 1
		}
	}
	return hex.EncodeToString(digest.Sum(nil)), nil
}

func digestSpanEnds(rows *sql.Rows) ([]int64, error) {
	defer rows.Close()

	page := make([]digestRowSize, 0, digestPageRows)
	for rows.Next() {
		var row digestRowSize
		if err := rows.Scan(&row.position, &row.bytes); err != nil {
			return nil, err
		}
		page = append(page, row)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if len(page) == 0 {
		return nil, errors.New("archive digest page has no rows")
	}

	slices.SortFunc(page, func(a, b digestRowSize) int { return cmp.Compare(a.position, b.position) })
	ends := make([]int64, 0, len(page))
	used := page[0].bytes
	for i, row := range page[1:] {
		if used+row.bytes > digestPageBytes {
			ends = append(ends, page[i].position)
			used = 0
		}
		used += row.bytes
	}
	return append(ends, page[len(page)-1].position), nil
}

func hashArchivePage(rows *sql.Rows, digest hash.Hash) error {
	defer rows.Close()

	page := make([]digestRow, 0, digestPageRows)
	for rows.Next() {
		var row digestRow
		fields := &row.fields
		if err := rows.Scan(&row.position, &fields[0], &fields[1], &fields[2],
			&fields[3], &fields[4], &fields[5], &fields[6], &fields[7]); err != nil {
			return err
		}
		page = append(page, row)
	}
	if err := rows.Err(); err != nil {
		return err
	}

	// Sort the bounded result here so DuckDB only sorts numeric positions and
	// sizes. Sorting the payload projection can allocate a full storage vector.
	slices.SortFunc(page, func(a, b digestRow) int { return cmp.Compare(a.position, b.position) })
	for _, row := range page {
		hashArchiveRow(digest, row.fields)
	}
	return nil
}

func hashArchiveRow(digest hash.Hash, fields [8]string) {
	// Length prefixes keep field boundaries independent of payload bytes.
	var length [8]byte
	for _, value := range fields {
		binary.BigEndian.PutUint64(length[:], uint64(len(value)))
		_, _ = digest.Write(length[:])
		_, _ = digest.Write([]byte(value))
	}
}
