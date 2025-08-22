// SPDX-License-Identifier: MIT
package storage

import (
	"context"
	"fmt"
	"io"
	"path/filepath"
	"time"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
	"github.com/sirupsen/logrus"
)

var log = logrus.New()

// Client represents a storage client for artifact management
type Client struct {
	client     *minio.Client
	bucketName string
}

// Config holds storage configuration
type Config struct {
	Endpoint        string
	AccessKeyID     string
	SecretAccessKey string
	UseSSL          bool
	BucketName      string
}

// NewClient creates a new storage client
func NewClient(cfg *Config) (*Client, error) {
	// Initialize MinIO client
	minioClient, err := minio.New(cfg.Endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.AccessKeyID, cfg.SecretAccessKey, ""),
		Secure: cfg.UseSSL,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create MinIO client: %w", err)
	}

	client := &Client{
		client:     minioClient,
		bucketName: cfg.BucketName,
	}

	// Ensure bucket exists
	ctx := context.Background()
	exists, err := minioClient.BucketExists(ctx, cfg.BucketName)
	if err != nil {
		return nil, fmt.Errorf("failed to check bucket existence: %w", err)
	}

	if !exists {
		err = minioClient.MakeBucket(ctx, cfg.BucketName, minio.MakeBucketOptions{})
		if err != nil {
			return nil, fmt.Errorf("failed to create bucket: %w", err)
		}
		log.Infof("Created bucket: %s", cfg.BucketName)
	}

	return client, nil
}

// UploadArtifact uploads an artifact to storage
func (c *Client) UploadArtifact(ctx context.Context, objectName string, reader io.Reader, size int64) (string, error) {
	// Add timestamp prefix to avoid collisions
	timestamp := time.Now().UTC().Format("20060102-150405")
	fullObjectName := fmt.Sprintf("%s/%s", timestamp, objectName)

	// Upload the artifact
	info, err := c.client.PutObject(ctx, c.bucketName, fullObjectName, reader, size, minio.PutObjectOptions{
		ContentType: "application/octet-stream",
		UserMetadata: map[string]string{
			"uploaded-at": time.Now().UTC().Format(time.RFC3339),
		},
	})
	if err != nil {
		return "", fmt.Errorf("failed to upload artifact: %w", err)
	}

	// Generate URI
	uri := fmt.Sprintf("minio://%s/%s", c.bucketName, fullObjectName)
	
	log.Infof("Uploaded artifact: %s (size: %d bytes)", uri, info.Size)
	return uri, nil
}

// DownloadArtifact downloads an artifact from storage
func (c *Client) DownloadArtifact(ctx context.Context, objectName string) (io.ReadCloser, error) {
	object, err := c.client.GetObject(ctx, c.bucketName, objectName, minio.GetObjectOptions{})
	if err != nil {
		return nil, fmt.Errorf("failed to get object: %w", err)
	}

	// Verify object exists by checking stat
	_, err = object.Stat()
	if err != nil {
		object.Close()
		return nil, fmt.Errorf("object not found: %w", err)
	}

	return object, nil
}

// UploadJobArtifacts uploads all artifacts for a job
func (c *Client) UploadJobArtifacts(ctx context.Context, jobID uint32, artifacts map[string]io.Reader) (map[string]string, error) {
	results := make(map[string]string)

	for name, reader := range artifacts {
		// Create object path
		objectName := fmt.Sprintf("jobs/%d/%s", jobID, name)
		
		// Get size if possible
		var size int64 = -1
		if sizer, ok := reader.(interface{ Size() int64 }); ok {
			size = sizer.Size()
		}

		uri, err := c.UploadArtifact(ctx, objectName, reader, size)
		if err != nil {
			return results, fmt.Errorf("failed to upload %s: %w", name, err)
		}

		results[name] = uri
	}

	return results, nil
}

// ListJobArtifacts lists all artifacts for a job
func (c *Client) ListJobArtifacts(ctx context.Context, jobID uint32) ([]string, error) {
	prefix := fmt.Sprintf("jobs/%d/", jobID)
	var artifacts []string

	// List objects with prefix
	objectCh := c.client.ListObjects(ctx, c.bucketName, minio.ListObjectsOptions{
		Prefix:    prefix,
		Recursive: true,
	})

	for object := range objectCh {
		if object.Err != nil {
			return artifacts, fmt.Errorf("error listing objects: %w", object.Err)
		}
		
		// Extract relative path
		relPath := filepath.Base(object.Key)
		artifacts = append(artifacts, relPath)
	}

	return artifacts, nil
}

// GetPresignedURL generates a presigned URL for artifact access
func (c *Client) GetPresignedURL(ctx context.Context, objectName string, expiry time.Duration) (string, error) {
	url, err := c.client.PresignedGetObject(ctx, c.bucketName, objectName, expiry, nil)
	if err != nil {
		return "", fmt.Errorf("failed to generate presigned URL: %w", err)
	}

	return url.String(), nil
}

// DeleteJobArtifacts removes all artifacts for a job
func (c *Client) DeleteJobArtifacts(ctx context.Context, jobID uint32) error {
	prefix := fmt.Sprintf("jobs/%d/", jobID)

	// List and delete all objects with prefix
	objectCh := c.client.ListObjects(ctx, c.bucketName, minio.ListObjectsOptions{
		Prefix:    prefix,
		Recursive: true,
	})

	for object := range objectCh {
		if object.Err != nil {
			return fmt.Errorf("error listing objects: %w", object.Err)
		}

		err := c.client.RemoveObject(ctx, c.bucketName, object.Key, minio.RemoveObjectOptions{})
		if err != nil {
			return fmt.Errorf("failed to delete %s: %w", object.Key, err)
		}
		
		log.Debugf("Deleted artifact: %s", object.Key)
	}

	return nil
}

// HealthCheck verifies storage connectivity
func (c *Client) HealthCheck(ctx context.Context) error {
	// Try to list buckets as a health check
	_, err := c.client.ListBuckets(ctx)
	if err != nil {
		return fmt.Errorf("storage health check failed: %w", err)
	}

	return nil
}