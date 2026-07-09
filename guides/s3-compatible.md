# S3-Compatible Services

ExOss supports any S3-compatible service using `provider: :custom`.

Supported services include:

- **MinIO** (self-hosted, local testing)
- **DigitalOcean Spaces**
- **Cloudflare R2**
- **Backblaze B2**
- **Wasabi**
- **Qiniu S3 API** (via `provider: :qiniu` for auto endpoint)

## Configuration

For custom providers, you must set `endpoint` explicitly. Typically you also need
`bucket_addressing: :path` (most S3-compatible services don't support virtual-hosted style).

### MinIO (Local Testing)

```elixir
config :my_app, MyApp.MinIOStorage,
  provider: :custom,
  endpoint: "http://localhost:9000",
  bucket_addressing: :path,
  access_key_id: "minioadmin",
  secret_access_key: "minioadmin"
```

### DigitalOcean Spaces

```elixir
config :my_app, MyApp.DOSpaces,
  provider: :custom,
  endpoint: "https://nyc3.digitaloceanspaces.com",
  bucket_addressing: :virtual,
  access_key_id: "...",
  secret_access_key: "...",
  region: "nyc3"
```

### Cloudflare R2

```elixir
config :my_app, MyApp.R2Storage,
  provider: :custom,
  endpoint: "https://{account_id}.r2.cloudflarestorage.com",
  bucket_addressing: :virtual,
  access_key_id: "...",
  secret_access_key: "..."
```

### Qiniu S3-Compatible API

For Qiniu's S3 API (not the native API), use `provider: :qiniu` for auto
endpoint construction:

```elixir
config :my_app, MyApp.QiniuStorage,
  provider: :qiniu,
  access_key_id: "...",
  secret_access_key: "...",
  region: "cn-east-1"
```

Endpoint is auto-constructed as `https://{bucket}.s3.{region}.qiniucs.com`.

## HTTPS and Custom Ports

For services using custom ports or HTTP (e.g., local MinIO):

```elixir
config :my_app, MyApp.MinIO,
  provider: :custom,
  endpoint: "https://minio.example.com:8443",
  ...
```

The scheme and port are parsed from the `endpoint` URL.