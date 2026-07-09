defmodule ExOss.CDN.Qiniu.Auth do
  @moduledoc """
  Authorization helpers for Qiniu CDN.

  Implements Qiniu's HMAC-SHA1 signing protocol for both upload tokens
  and download URL authorization.

  See [Qiniu Security Documentation](http://developer.qiniu.com/docs/v6/api/reference/security/).
  """

  alias ExOss.Client.Client
  alias ExOss.CDN.Qiniu.PutPolicy
  alias ExOss.Utils

  @spec generate_uptoken(Client.t(), PutPolicy.t()) :: String.t()
  def generate_uptoken(%Client{} = client, %PutPolicy{} = put_policy) do
    {access_key, secret_key} = credentials_from_client(client)
    encoded_put_policy = PutPolicy.encoded_json(put_policy)
    encoded_sign = hex_digest(secret_key, encoded_put_policy)

    "#{access_key}:#{encoded_sign}:#{encoded_put_policy}"
  end

  @spec authorize_download_url(Client.t(), binary(), non_neg_integer()) :: binary()
  def authorize_download_url(%Client{cdn: %{endpoint: endpoint}} = client, res_key, expires_in) do
    url = Path.join(endpoint, res_key)
    deadline = Utils.deadline_unix(expires_in)

    parsed = url |> URI.encode() |> URI.parse()

    query =
      (parsed.query || "")
      |> URI.decode_query()
      |> Map.merge(%{"e" => deadline})
      |> URI.encode_query()

    download_url = %{parsed | query: query} |> to_string

    {access_key, secret_key} = credentials_from_client(client)
    encoded_sign = hex_digest(secret_key, download_url)
    down_token = access_key <> ":" <> encoded_sign

    "#{download_url}&token=#{down_token}"
  end

  @doc false
  def hex_digest(key, data) when is_binary(key) and is_binary(data) do
    :crypto.mac(:hmac, :sha, key, data) |> Base.url_encode64()
  end

  defp credentials_from_client(%Client{
         access_key_id: access_key,
         secret_access_key: secret_key
       })
       when is_binary(access_key) and is_binary(secret_key) do
    {access_key, secret_key}
  end
end
