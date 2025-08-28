// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"fmt"
	"io"
	"os"
	"time"

	"github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var (
	cfgFile string
	verbose bool
)

var rootCmd = &cobra.Command{
	Use:   "wargame-storage",
	Short: "Storage management for Qubic Wargame Grid",
	Long:  `A CLI tool for managing artifacts in the Qubic Wargame Grid storage system.`,
}

var uploadCmd = &cobra.Command{
	Use:   "upload [file] [object-name]",
	Short: "Upload a file to storage",
	Args:  cobra.ExactArgs(2),
	RunE: func(cmd *cobra.Command, args []string) error {
		client, err := createClient()
		if err != nil {
			return err
		}

		file, err := os.Open(args[0])
		if err != nil {
			return fmt.Errorf("failed to open file: %w", err)
		}
		defer file.Close()

		stat, err := file.Stat()
		if err != nil {
			return fmt.Errorf("failed to stat file: %w", err)
		}

		ctx := context.Background()
		uri, err := client.UploadArtifact(ctx, args[1], file, stat.Size())
		if err != nil {
			return err
		}

		fmt.Printf("Uploaded successfully: %s\n", uri)
		return nil
	},
}

var downloadCmd = &cobra.Command{
	Use:   "download [object-name] [output-file]",
	Short: "Download a file from storage",
	Args:  cobra.ExactArgs(2),
	RunE: func(cmd *cobra.Command, args []string) error {
		client, err := createClient()
		if err != nil {
			return err
		}

		ctx := context.Background()
		reader, err := client.DownloadArtifact(ctx, args[0])
		if err != nil {
			return err
		}
		defer reader.Close()

		out, err := os.Create(args[1])
		if err != nil {
			return fmt.Errorf("failed to create output file: %w", err)
		}
		defer out.Close()

		n, err := io.Copy(out, reader)
		if err != nil {
			return fmt.Errorf("failed to write file: %w", err)
		}

		fmt.Printf("Downloaded %d bytes to %s\n", n, args[1])
		return nil
	},
}

var listCmd = &cobra.Command{
	Use:   "list [job-id]",
	Short: "List artifacts for a job",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		client, err := createClient()
		if err != nil {
			return err
		}

		var jobID uint32
		_, err = fmt.Sscanf(args[0], "%d", &jobID)
		if err != nil {
			return fmt.Errorf("invalid job ID: %w", err)
		}

		ctx := context.Background()
		artifacts, err := client.ListJobArtifacts(ctx, jobID)
		if err != nil {
			return err
		}

		fmt.Printf("Artifacts for job %d:\n", jobID)
		for _, artifact := range artifacts {
			fmt.Printf("  - %s\n", artifact)
		}

		return nil
	},
}

var presignCmd = &cobra.Command{
	Use:   "presign [object-name]",
	Short: "Generate a presigned URL",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		client, err := createClient()
		if err != nil {
			return err
		}

		expiry, _ := cmd.Flags().GetDuration("expiry")
		
		ctx := context.Background()
		url, err := client.GetPresignedURL(ctx, args[0], expiry)
		if err != nil {
			return err
		}

		fmt.Printf("Presigned URL (valid for %s):\n%s\n", expiry, url)
		return nil
	},
}

var healthCmd = &cobra.Command{
	Use:   "health",
	Short: "Check storage health",
	RunE: func(cmd *cobra.Command, args []string) error {
		client, err := createClient()
		if err != nil {
			return err
		}

		ctx := context.Background()
		if err := client.HealthCheck(ctx); err != nil {
			return err
		}

		fmt.Println("Storage is healthy")
		return nil
	},
}

func init() {
	cobra.OnInitialize(initConfig)

	rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is $HOME/.wargame-storage.yaml)")
	rootCmd.PersistentFlags().BoolVarP(&verbose, "verbose", "v", false, "verbose output")

	// Add subcommands
	rootCmd.AddCommand(uploadCmd)
	rootCmd.AddCommand(downloadCmd)
	rootCmd.AddCommand(listCmd)
	rootCmd.AddCommand(presignCmd)
	rootCmd.AddCommand(healthCmd)

	// Presign command flags
	presignCmd.Flags().Duration("expiry", 1*time.Hour, "URL expiry duration")
}

func initConfig() {
	if cfgFile != "" {
		viper.SetConfigFile(cfgFile)
	} else {
		home, err := os.UserHomeDir()
		cobra.CheckErr(err)

		viper.AddConfigPath(home)
		viper.SetConfigType("yaml")
		viper.SetConfigName(".wargame-storage")
	}

	// Environment variables
	viper.SetEnvPrefix("WARGAME_STORAGE")
	viper.AutomaticEnv()

	// Defaults
	viper.SetDefault("endpoint", "localhost:9000")
	viper.SetDefault("access_key_id", "minioadmin")
	viper.SetDefault("secret_access_key", "minioadmin")
	viper.SetDefault("use_ssl", false)
	viper.SetDefault("bucket_name", "wargame-artifacts")

	if err := viper.ReadInConfig(); err == nil && verbose {
		fmt.Fprintln(os.Stderr, "Using config file:", viper.ConfigFileUsed())
	}

	// Configure logging
	if verbose {
		logrus.SetLevel(logrus.DebugLevel)
	} else {
		logrus.SetLevel(logrus.InfoLevel)
	}
}

func createClient() (*Client, error) {
	cfg := &Config{
		Endpoint:        viper.GetString("endpoint"),
		AccessKeyID:     viper.GetString("access_key_id"),
		SecretAccessKey: viper.GetString("secret_access_key"),
		UseSSL:          viper.GetBool("use_ssl"),
		BucketName:      viper.GetString("bucket_name"),
	}

	return NewClient(cfg)
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}