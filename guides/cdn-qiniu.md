# Qiniu CDN

Qiniu CDN integration for signed download URLs and upload tokens.

## How It Works

ExOss's Qiniu CDN adapter is **entirely self-contained** — it implements
Qiniu's HMAC-SHA1 signing protocol directly and does not depend on the
`qiniu` hex package.

- **Download URLs**: Signed with HMAC-SHA1 over the full URL (including a
  deadline `e` parameter), producing a `token` query parameter.
- **Upload tokens**: A [PutPolicy](ExOss.CDN.Qiniu.PutPolicy.html) JSON
  is Base64 url-safe encoded and signed, producing an `uptoken` string.

## Configuration

```elixir
config :my_app, MyApp.Storage,
  provider: :custom,
  endpoint: "https://s3.cn-east-1.qiniucs.com",
  access_key_id: "your-qiniu-access-key",
  secret_access_key: "your-qiniu-secret-key",
  region: "cn-east-1",
  cdn: [
    provider: :qiniu,
    endpoint: "https://cdn.example.com"
  ]
```

> The `access_key_id` and `secret_access_key` are shared between storage
> and CDN. Qiniu uses the same credentials for both S3-compatible storage
> and CDN signing.

### Fields

| Field | Description |
|-------|-------------|
| `provider` | Must be `:qiniu` |
| `endpoint` | Qiniu CDN domain |

## Usage

```elixir
# Signed download URL with token
MyApp.Storage.authorize_download_url("bucket", "photos/cat.jpg", 3600)
# => "https://cdn.example.com/photos/cat.jpg?e=1234567890&token=AK:SIG"

# Upload token
credential = MyApp.Storage.upload_credential("bucket", "photos/cat.jpg", 3600)
credential.uptoken
# => "AK:SIG:ENCODED_POLICY"
credential.presigned_url
# => nil  (presigned_url is for S3/CloudFront only)
credential.endpoint
# => "https://cdn.example.com"
```

## Content-Disposition

Use `:att_name` to set the download filename:

```elixir
MyApp.Storage.authorize_download_url("bucket", "photos/cat.jpg", 3600, att_name: "cat.jpg")
# => "https://cdn.example.com/photos/cat.jpg?e=...&token=...&attname=cat.jpg"
```

## See Also

- `ExOss.CDN.Qiniu` — adapter implementation
- `ExOss.CDN.Qiniu.Auth` — HMAC-SHA1 signing helpers
- `ExOss.CDN.Qiniu.PutPolicy` — upload policy builder