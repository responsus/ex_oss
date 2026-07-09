# ExOss

[![ hex](https://img.shields.io/hexpm/v/ex_oss.svg)](https://hex.pm/packages/ex_oss)
[![Docs](https://img.shields.io/badge/hexdocs-docs-orange.svg)](https://hexdocs.pm/ex_oss)

A unified **S3-compatible object storage** library for Elixir with **multi-CDN** support.

## Features

- **S3 unified storage** — AWS S3, Qiniu S3, MinIO, DigitalOcean Spaces, Cloudflare R2, or any S3-compatible service
- **Multi-CDN** — CloudFront, Qiniu CDN, and extensible via `ExOss.CDN.Behaviour`
- **Multi-client** — configure multiple storage backends and CDNs side by side
- **File transfer** — upload from file, content, remote URL, or cloud-to-cloud copy
- **Presigned URLs** — temporary direct-access upload/download without exposing credentials

## Installation

Add `ex_oss` to your dependencies:

```elixir
def deps do
  [
    {:ex_oss, "~> 1.0"}
  ]
end
```

## Quick Start

```elixir
# 1. Define a storage module
defmodule MyApp.Storage do
  use ExOss, otp_app: :my_app
end

# 2. Add configuration
config :my_app, MyApp.Storage,
  provider: :aws,
  access_key_id: "your-access-key",
  secret_access_key: "your-secret-key",
  region: "us-east-1"

# 3. Use it
MyApp.Storage.upload_credential("bucket", "path/file.jpg", 3600)
MyApp.Storage.authorize_download_url("bucket", "path/file.jpg", 3600)
```

See the [getting started guide](https://hexdocs.pm/ex_oss/getting-started.html) for details.

## License

MIT
