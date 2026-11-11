// Package storage wraps MinIO object storage for KYC document uploads.
// Documents are uploaded by clients directly via presigned PUT URLs so the
// PII never transits user-service.
package storage

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

// MinIOStore holds the MinIO client and bucket config.
type MinIOStore struct {
	client    *minio.Client
	bucket    string
	logger    *log.Logger
	available bool
}

// NewMinIOStore connects to MinIO and ensures the bucket exists.
// A failed connection is logged but not fatal: KYC submission still works
// without uploads (documents become optional, matching demo behavior).
func NewMinIOStore(endpoint, accessKey, secretKey, bucket string, secure bool) *MinIOStore {
	s := &MinIOStore{
		bucket: bucket,
		logger: log.New(log.Writer(), "[minio] ", log.LstdFlags|log.Lshortfile),
	}
	client, err := minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(accessKey, secretKey, ""),
		Secure: secure,
	})
	if err != nil {
		s.logger.Printf("⚠️ MinIO init failed: %v (uploads disabled, KYC continues without documents)", err)
		return s
	}
	s.client = client

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := client.MakeBucket(ctx, bucket, minio.MakeBucketOptions{}); err != nil {
		exists, errCheck := client.BucketExists(ctx, bucket)
		if errCheck != nil || !exists {
			s.logger.Printf("⚠️ MinIO bucket %q unavailable: %v (uploads disabled)", bucket, err)
			return s
		}
	}
	s.available = true
	s.logger.Printf("✅ Connected to MinIO at %s, bucket %q ready", endpoint, bucket)
	return s
}

// Available reports whether uploads are usable.
func (s *MinIOStore) Available() bool { return s.available }

// ensureBucket re-checks the bucket before each presign: the S3 server may be
// recreated with empty storage between user-service restarts (dev containers
// wiped), which otherwise surfaces as 403/404 on every upload until restart.
func (s *MinIOStore) ensureBucket(ctx context.Context) error {
	exists, err := s.client.BucketExists(ctx, s.bucket)
	if err != nil {
		return fmt.Errorf("check bucket: %w", err)
	}
	if exists {
		return nil
	}
	if err := s.client.MakeBucket(ctx, s.bucket, minio.MakeBucketOptions{}); err != nil {
		return fmt.Errorf("recreate bucket: %w", err)
	}
	s.logger.Printf("✅ Recreated missing bucket %q", s.bucket)
	return nil
}

// PresignPut returns a presigned PUT URL for the object key.
func (s *MinIOStore) PresignPut(ctx context.Context, objectKey string, ttl time.Duration) (string, error) {
	if !s.available {
		return "", fmt.Errorf("object storage unavailable")
	}
	if err := s.ensureBucket(ctx); err != nil {
		return "", err
	}
	url, err := s.client.PresignedPutObject(ctx, s.bucket, objectKey, ttl)
	if err != nil {
		return "", fmt.Errorf("presign put: %w", err)
	}
	return url.String(), nil
}

// PresignGet returns a presigned GET URL for the object key (admin document review).
func (s *MinIOStore) PresignGet(ctx context.Context, objectKey string, ttl time.Duration) (string, error) {
	if !s.available {
		return "", fmt.Errorf("object storage unavailable")
	}
	if err := s.ensureBucket(ctx); err != nil {
		return "", err
	}
	url, err := s.client.PresignedGetObject(ctx, s.bucket, objectKey, ttl, nil)
	if err != nil {
		return "", fmt.Errorf("presign get: %w", err)
	}
	return url.String(), nil
}
