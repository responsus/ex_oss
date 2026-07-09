defmodule ExOss.CDN.CloudFront do
  @moduledoc """
  CloudFront CDN adapter.

  Implements `ExOss.CDN.Behaviour` to generate signed CloudFront URLs
  for both download and upload operations.

  CloudFront signed URLs use an RSA-SHA1 signature over a JSON policy
  document, along with `Key-Pair-Id`, `Expires`, `Signature`, and
  `Policy` query parameters.

  ## Configuration

      config :my_app, MyApp.Storage,
        cdn: [
          provider: :cloudfront,
          endpoint: "https://d123456789.cloudfront.net",
          aws_key_id: "K2XXXXXXXXXXXXX",
          aws_private_key: "-----BEGIN RSA PRIVATE KEY-----\\n..."
        ]
  """

  @behaviour ExOss.CDN.Behaviour

  alias ExOss.Client.CDN
  alias ExOss.Client.Client
  alias ExOss.UploadCredential
  alias ExOss.Utils

  @impl true
  @spec authorize_download_url(Client.t(), binary(), binary(), non_neg_integer(), keyword()) ::
          binary()
  def authorize_download_url(
        %Client{cdn: %CDN{endpoint: endpoint, aws_key_id: key_id, aws_private_key: private_key}},
        _bucket,
        res_key,
        expires_in,
        opts
      )
      when is_binary(endpoint) and is_binary(key_id) and is_binary(private_key) do
    disposition =
      case opts[:att_name] do
        nil ->
          ""

        name ->
          [
            {"response-content-disposition",
             "attachment; filename=#{name}; filename*=utf-8''#{name}"}
          ]
          |> URI.encode_query(:rfc3986)
      end

    unsigned_url = endpoint <> "/" <> URI.encode(res_key) <> "?" <> disposition

    deadline = Utils.deadline_unix(expires_in)
    policy = policy(unsigned_url, deadline)
    signature = sign(policy, private_key)

    signed_query =
      [
        {"Expires", deadline},
        {"Signature", signature},
        {"Key-Pair-Id", key_id},
        {"Policy", Base.encode64(policy)}
      ]
      |> URI.encode_query(:rfc3986)

    unsigned_url <> "&" <> signed_query
  end

  @impl true
  @spec upload_credential(Client.t(), binary(), binary(), non_neg_integer()) ::
          UploadCredential.t()
  def upload_credential(
        %Client{cdn: %CDN{endpoint: endpoint}} = client,
        bucket,
        res_key,
        expires_in
      ) do
    %UploadCredential{
      uptoken: nil,
      presigned_url: authorize_download_url(client, bucket, res_key, expires_in, []),
      res_key: res_key,
      endpoint: endpoint
    }
  end

  defp policy(url, deadline) do
    policy =
      %{
        "Statement" => [
          %{
            "Resource" => url,
            "Condition" => %{"DateLessThan" => %{"AWS:EpochTime" => deadline}}
          }
        ]
      }

    Utils.json_codec().encode!(policy)
  end

  @spec sign(binary(), binary()) :: binary()
  def sign(policy, private_key) do
    [{_, _, _} = entry] = :public_key.pem_decode(private_key)
    key = :public_key.pem_entry_decode(entry)

    policy
    |> :public_key.sign(:sha, key)
    |> Base.encode64()
    |> String.replace("+", "-")
    |> String.replace("/", "~")
    |> String.replace("=", "_")
  end
end
