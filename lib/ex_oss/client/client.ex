defmodule ExOss.Client.Client do
  @moduledoc """
  Client configuration struct.

  ## Required Fields

  | Field | Type | Description |
  |-------|------|-------------|
  | `provider` | `:aws` \| `:qiniu` \| `:custom` | Storage provider |
  | `access_key_id` | `String.t()` | Access key |
  | `secret_access_key` | `String.t()` | Secret key |

  ## Optional Fields

  | Field | Type | Default | Description |
  |-------|------|---------|-------------|
  | `region` | `String.t()` | `"us-east-1"` | Storage region |
  | `endpoint` | `String.t()` | auto | Custom endpoint URL |
  | `bucket` | `String.t()` | `nil` | Default bucket |
  | `scheme` | `String.t()` | `"https://"` | URL scheme |
  | `port` | `integer()` | `443` | Port number |
  | `bucket_addressing` | `:virtual` \| `:path` | `:virtual` | Bucket addressing style |
  | `cdn_upload` | `boolean()` | `true` | Use CDN for uploads |
  | `cdn_download` | `boolean()` | `true` | Use CDN for downloads |
  | `cdn` | `CDN.t()` | `nil` | CDN configuration |

  ## Region Values

  **AWS S3**: `"us-east-1"`, `"us-west-2"`, `"eu-west-1"`, `"ap-northeast-1"`, etc.

  **Qiniu (S3)**: `"cn-east-1"`, `"cn-north-1"`, `"cn-south-1"`, etc.

  **Custom**: Any S3-compatible service (MinIO, DigitalOcean Spaces, Cloudflare R2, etc.)
  """

  alias ExOss.Client.CDN

  @enforce_keys [:provider, :access_key_id, :secret_access_key]
  defstruct [
    :provider,
    :access_key_id,
    :secret_access_key,
    :endpoint,
    :bucket,
    :cdn,
    scheme: "https://",
    port: 443,
    region: "us-east-1",
    cdn_upload: true,
    cdn_download: true,
    bucket_addressing: :virtual
  ]

  @type t :: %__MODULE__{
          provider: :aws | :qiniu | :custom,
          access_key_id: String.t(),
          secret_access_key: String.t(),
          region: String.t() | nil,
          scheme: String.t(),
          port: non_neg_integer(),
          endpoint: String.t() | nil,
          bucket: String.t() | nil,
          cdn: CDN.t() | nil,
          cdn_upload: boolean(),
          cdn_download: boolean(),
          bucket_addressing: :path | :virtual
        }

  @doc false
  def validate_provider!(provider) do
    if provider in [:aws, :qiniu, :custom] do
      :ok
    else
      raise ArgumentError,
            "Invalid ExOss provider: #{inspect(provider)}. Supported providers are :aws, :qiniu, :custom."
    end
  end
end

defimpl Inspect, for: ExOss.Client.Client do
  def inspect(client, opts) do
    redacted = %{
      client
      | access_key_id: redact(client.access_key_id),
        secret_access_key: redact(client.secret_access_key)
    }

    Inspect.Any.inspect(redacted, opts)
  end

  defp redact(nil), do: nil
  defp redact(_), do: "**REDACTED**"
end
