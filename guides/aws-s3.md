# AWS S3

Configuration for standard AWS S3.

## Basic Configuration

```elixir
config :my_app, MyApp.Storage,
  provider: :aws,
  access_key_id: "AKIAIOSFODNN7EXAMPLE",
  secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
  region: "us-east-1"
```

## Region

AWS S3 endpoints are auto-constructed as `https://{bucket}.s3.{region}.amazonaws.com`
using virtual-hosted style addressing.

Common regions:

| Region | Endpoint |
|--------|----------|
| `us-east-1` | `s3.us-east-1.amazonaws.com` |
| `us-west-2` | `s3.us-west-2.amazonaws.com` |
| `eu-west-1` | `s3.eu-west-1.amazonaws.com` |
| `ap-northeast-1` | `s3.ap-northeast-1.amazonaws.com` |

## Bucket Addressing

Default is `:virtual` (virtual-hosted style): `https://{bucket}.s3.{region}.amazonaws.com`

To use path style (rare for AWS), set `bucket_addressing: :path`:

```elixir
config :my_app, MyApp.Storage,
  provider: :aws,
  bucket_addressing: :path,
  ...
```

## With CloudFront CDN

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

See [CloudFront CDN guide](cdn-cloudfront.html) for details.