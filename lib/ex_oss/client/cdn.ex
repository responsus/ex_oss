defmodule ExOss.Client.CDN do
  @moduledoc """
  CDN configuration struct.

  ## Fields

  | Field | Type | Required | Description |
  |-------|------|----------|-------------|
  | `endpoint` | `String.t()` | Yes | CDN domain URL |
  | `provider` | `:cloudfront` \| `:qiniu` | Yes | CDN provider |
  | `module` | `module()` | Yes | Resolved CDN adapter module |
  | `aws_key_id` | `String.t()` | CloudFront | Key pair ID |
  | `aws_private_key` | `String.t()` | CloudFront | RSA private key (PEM) |

  ## Example

      cdn: [
        provider: :cloudfront,
        endpoint: "https://d123456789.cloudfront.net",
        aws_key_id: "K2XXXXXXXXXXXXX",
        aws_private_key: "-----BEGIN RSA PRIVATE KEY-----\\n..."
      ]
  """

  @enforce_keys [:endpoint, :provider]
  defstruct [
    :endpoint,
    :provider,
    :module,
    :aws_key_id,
    :aws_private_key
  ]

  @type t :: %__MODULE__{
          endpoint: String.t(),
          provider: :cloudfront | :qiniu,
          module: module() | nil,
          aws_key_id: String.t() | nil,
          aws_private_key: String.t() | nil
        }

  @doc false
  def validate_provider!(provider) do
    if provider in [:cloudfront, :qiniu] do
      :ok
    else
      raise ArgumentError,
            "Invalid CDN provider: #{inspect(provider)}. Supported CDN providers are :cloudfront and :qiniu."
    end
  end
end

defimpl Inspect, for: ExOss.Client.CDN do
  def inspect(cdn, opts) do
    redacted = %{
      cdn
      | aws_key_id: redact(cdn.aws_key_id),
        aws_private_key: redact(cdn.aws_private_key)
    }

    Inspect.Any.inspect(redacted, opts)
  end

  defp redact(nil), do: nil
  defp redact(_), do: "**REDACTED**"
end
