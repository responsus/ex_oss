# Getting Started

`ExOss` is a unified S3-compatible object storage library with multi-CDN support.

## Overview

ExOss supports:

- **Storage**: Any S3-compatible service — AWS S3, Qiniu S3, MinIO, DigitalOcean Spaces, Cloudflare R2, etc.
- **CDN**: CloudFront, Qiniu CDN, and any custom CDN via `ExOss.CDN.Behaviour`
- **File transfer**: Upload from local file, content, remote URL, or cloud-to-cloud copy
- **Presigned URLs**: Temporary upload/download URLs without exposing credentials

## Installation

Add `ex_oss` to your `mix.exs`:

```elixir
def deps do
  [
    {:ex_aws_s3, "~> 2.0"}
    {:ex_oss, "~> 0.1.0"}
  ]
end
```

> `ex_aws_s3` is the underlying S3 client. ExOss wraps it with configuration
> convenience, multi-provider support, and CDN integration.

## Quick Start

### 1. Define a Storage Module

```elixir
defmodule MyApp.Storage do
  use ExOss, otp_app: :my_app
end
```

### 2. Configure

```elixir
# config/config.exs
config :my_app, MyApp.Storage,
  provider: :aws,
  access_key_id: "AKIAIOSFODNN7EXAMPLE",
  secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
  region: "us-east-1"
```

### 3. Use

```elixir
# Generate a presigned download URL (valid for 1 hour)
MyApp.Storage.authorize_download_url("bucket", "photos/cat.jpg", 3600)

# Generate upload credentials for direct-to-S3 upload
credential = MyApp.Storage.upload_credential("bucket", "photos/cat.jpg", 3600)
Req.put!(credential.presigned_url, body: file_content)

# Generate a public (unsigned) URL
MyApp.Storage.public_url("bucket", "photos/cat.jpg")

# Retrieve file metadata
{:ok, %{file_size: 1024, mime_type: "image/jpeg"}} = MyApp.Storage.metadata("bucket", "photos/cat.jpg")
```

## Providers

ExOss supports three provider modes:

| Provider | Endpoint | Description |
|----------|---------|-------------|
| `:aws` | Auto: `s3.{region}.amazonaws.com` | Standard AWS S3 |
| `:qiniu` | Auto: `s3.{region}.qiniucs.com` | Qiniu S3-compatible API |
| `:custom` | Manual: set `endpoint` | MinIO, DigitalOcean Spaces, Cloudflare R2, etc. |

For custom providers, you must set the `endpoint` and typically `bucket_addressing: :path`:

```elixir
config :my_app, MyApp.MinIO,
  provider: :custom,
  endpoint: "http://localhost:9000",
  bucket_addressing: :path,
  access_key_id: "minioadmin",
  secret_access_key: "minioadmin"
```

## Multi-Client

You can define multiple storage modules for different backends:

```elixir
defmodule MyApp.AWSStorage do
  use ExOss, otp_app: :my_app
end

defmodule MyApp.MinIOStorage do
  use ExOss, otp_app: :my_app
end

config :my_app, MyApp.AWSStorage,
  provider: :aws,
  access_key_id: "...",
  secret_access_key: "...",
  region: "us-east-1"

config :my_app, MyApp.MinIOStorage,
  provider: :custom,
  endpoint: "http://localhost:9000",
  bucket_addressing: :path,
  access_key_id: "minioadmin",
  secret_access_key: "minioadmin"
```

Or build clients programmatically:

```elixir
aws = ExOss.Client.new(provider: :aws, access_key_id: "...", ...)
minio = ExOss.Client.new(provider: :custom, endpoint: "...", ...)

ExOss.Runner.upload_credential(aws, "bucket", "key")
ExOss.Runner.public_url(minio, "bucket", "key")
```

## Next Steps

- [AWS S3](aws-s3.html) — detailed AWS S3 configuration
- [S3-Compatible Services](s3-compatible.html) — MinIO, DigitalOcean, Cloudflare R2
- [CloudFront CDN](cdn-cloudfront.html) — signed CloudFront URLs
- [Qiniu CDN](cdn-qiniu.html) — Qiniu CDN auth tokens
- [File Transfer](file-transfer.html) — upload, copy, delete operations