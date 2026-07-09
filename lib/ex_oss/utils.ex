defmodule ExOss.Utils do
  @moduledoc """
  Internal utility functions for URL construction, deadline computation,
  and JSON codec resolution.

  ## JSON Codec

  The JSON codec is resolved at compile time via application config:

      config :ex_oss, :json_codec, Jason

  Defaults to the `JSON` module if not configured.
  """

  alias ExOss.Client.Client

  @json_codec Application.compile_env(:ex_oss, :json_codec, JSON)

  @doc """
  Builds a public (unsigned) URL from client, bucket, and resource key.

  Handles both virtual-hosted style and path style addressing:

  ## Examples

      iex> client = %ExOss.Client.Client{endpoint: "https://bucket.s3.us-east-1.amazonaws.com", bucket_addressing: :virtual}
      iex> ExOss.Utils.public_url(client, "bucket", "folder/file.txt")
      "https://bucket.s3.us-east-1.amazonaws.com/folder/file.txt"

      iex> client = %ExOss.Client.Client{endpoint: "https://minio.example.com:9000", bucket_addressing: :path}
      iex> ExOss.Utils.public_url(client, "bucket", "folder/file.txt")
      "https://minio.example.com:9000/bucket/folder/file.txt"
  """
  @spec public_url(Client.t(), binary(), binary()) :: binary()
  def public_url(%Client{endpoint: endpoint, bucket_addressing: :virtual}, _bucket, res_key) do
    "#{endpoint}/#{URI.encode(res_key)}"
  end

  def public_url(%Client{endpoint: endpoint, bucket_addressing: :path}, bucket, res_key) do
    "#{endpoint}/#{bucket}/#{URI.encode(res_key)}"
  end

  @doc """
  Computes a Unix deadline timestamp from a starting time plus an offset in seconds.

  ## Examples

      iex> ExOss.Utils.deadline_unix(~U[2024-01-01 00:00:00Z], 3600)
      1704067600
  """
  @spec deadline_unix(DateTime.t(), non_neg_integer()) :: integer()
  def deadline_unix(begin_time \\ DateTime.utc_now(), expires_in) do
    begin_time
    |> DateTime.add(expires_in, :second)
    |> DateTime.to_unix()
  end

  @doc """
  Converts a snake_case atom or string to lowerCamelCase.

  ## Examples

      iex> ExOss.Utils.camelize(:force_save_key)
      "forceSaveKey"

      iex> ExOss.Utils.camelize("persistent_ops")
      "persistentOps"
  """
  @spec camelize(atom() | String.t()) :: String.t()
  def camelize(string) do
    string |> to_string |> Macro.camelize() |> uncapitalize()
  end

  defp uncapitalize(str) do
    {first, rest} = String.split_at(str, 1)
    String.downcase(first) <> rest
  end

  @doc """
  Returns the configured JSON codec module.
  """
  @spec json_codec() :: module()
  def json_codec do
    @json_codec
  end
end
