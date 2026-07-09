# CloudFront CDN

AWS CloudFront CDN integration for signed download and upload URLs.

## How It Works

When CDN is configured and `cdn_download`/`cdn_upload` are enabled (default:
`true`), ExOss routes download URL and upload credential requests through
the CloudFront adapter instead of generating S3 presigned URLs.

CloudFront signed URLs use RSA-SHA1 to sign a JSON policy document,
appending `Expires`, `Signature`, `Key-Pair-Id`, and `Policy` query
parameters to the URL.

## Configuration

```elixir
config :my_app, MyApp.Storage,
  provider: :aws,
  access_key_id: "...",
  secret_access_key: "...",
  region: "us-east-1",
  cdn: [
    provider: :cloudfront,
    endpoint: "https://d123456789.cloudfront.net",
    aws_key_id: "K2XXXXXXXXXXXXX",
    aws_private_key: "-----BEGIN RSA PRIVATE KEY-----\n..."
  ]
```

### Fields

| Field | Description |
|-------|-------------|
| `provider` | Must be `:cloudfront` |
| `endpoint` | CloudFront distribution domain |
| `aws_key_id` | CloudFront key pair ID |
| `aws_private_key` | RSA private key (PEM format) |

> The key pair must be created in the AWS Console under CloudFront's
> "Public key" settings. The private key is in PEM format.

## Usage

```elixir
# Signed download URL
MyApp.Storage.authorize_download_url("bucket", "photos/cat.jpg", 3600)
# => "https://d123456789.cloudfront.net/photos/cat.jpg?Expires=...&Signature=...&Key-Pair-Id=...&Policy=..."

# Upload credential (CloudFront signed PUT URL)
credential = MyApp.Storage.upload_credential("bucket", "photos/cat.jpg", 3600)
credential.presigned_url
# => "https://d123456789.cloudfront.net/photos/cat.jpg?...&Signature=..."
credential.uptoken
# => nil  (uptoken is for Qiniu CDN only)
```

## Content-Disposition

To set a download filename, use the `:att_name` option:

```elixir
MyApp.Storage.authorize_download_url("bucket", "photos/cat.jpg", 3600, att_name: "cat.jpg")
```

This adds a `response-content-disposition` query parameter with an
`attachment; filename=cat.jpg` header.

## Disabling CDN

To use S3 presigned URLs instead of CloudFront signed URLs:

```elixir
config :my_app, MyApp.Storage,
  cdn_download: false,
  cdn_upload: false,
  ...
```

Or per-request by building the client programmatically:

```elixir
client = ExOss.Client.new(base_client, cdn_download: false)
```

## See Also

- `ExOss.CDN.CloudFront` — adapter implementation
- `ExOss.CDN.Behaviour` — CDN adapter behaviour