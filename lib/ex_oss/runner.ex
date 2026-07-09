defmodule ExOss.Runner do
  @moduledoc """
  Executes storage operations with an explicit client.

  The `Runner` is the central dispatch layer between storage and CDN.
  When a CDN is configured and enabled (`cdn_download: true` /
  `cdn_upload: true`), download URLs and upload credentials are
  routed through the CDN adapter. Otherwise, they fall back to S3
  presigned URLs via `ExOss.Storage`.

  ## Usage with Explicit Client

      client = ExOss.Client.new(
        provider: :aws,
        access_key_id: "...",
        secret_access_key: "...",
        region: "us-east-1",
        cdn: [provider: :cloudfront, endpoint: "https://cdn.example.com", ...]
      )

      ExOss.Runner.public_url(client, "bucket", "file.jpg")
      ExOss.Runner.authorize_download_url(client, "bucket", "file.jpg", 3600, [])
      ExOss.Runner.upload_credential(client, "bucket", "file.jpg", 3600)

  For config-based convenience methods, use `use ExOss` instead.
  """

  alias ExOss.CDN, as: CDNService
  alias ExOss.Client.CDN
  alias ExOss.Client.Client
  alias ExOss.Storage
  alias ExOss.Utils

  @doc """
  Executes a storage task (upload, copy, delete, etc.).

  See `ExOss.Storage.run/2` for supported task patterns.
  """
  @spec run(Client.t(), ExOss.StorageTask.t()) ::
          {:ok, binary() | nil} | {:error, binary()}
  def run(client, task) do
    Storage.run(client, task)
  end

  @doc """
  Retrieves metadata for a stored object.
  """
  @spec metadata(Client.t(), binary(), binary()) ::
          {:ok, %{file_size: non_neg_integer(), mime_type: binary()}} | {:error, :no_metadata}
  def metadata(client, bucket, res_key) do
    Storage.metadata(client, bucket, res_key)
  end

  @doc """
  Generates a signed download URL.

  If CDN is enabled and configured, routes to the CDN adapter
  (e.g., CloudFront signed URL or Qiniu CDN signed URL).
  Otherwise, falls back to S3 presigned URL.

  ## Options

    * `:att_name` — download filename for Content-Disposition
    * `:query_params` — additional query parameters (S3 only)
    * `:headers` — headers to include in signature (S3 only)
  """
  @spec authorize_download_url(Client.t(), binary(), binary(), non_neg_integer(), keyword()) ::
          binary()
  def authorize_download_url(
        %Client{cdn_download: true, cdn: %CDN{endpoint: endpoint}} = client,
        bucket,
        res_key,
        expires_in,
        opts
      )
      when is_binary(endpoint) do
    CDNService.authorize_download_url(client, bucket, res_key, expires_in, opts)
  end

  def authorize_download_url(client, bucket, res_key, expires_in, opts) do
    client
    |> attach_download_endpoint(bucket)
    |> Storage.authorize_download_url(bucket, res_key, expires_in, opts)
  end

  @doc """
  Generates upload credentials for the given resource key.

  If CDN is enabled and configured, routes to the CDN adapter.
  Otherwise, falls back to S3 presigned PUT URL.
  """
  @spec upload_credential(Client.t(), binary(), binary(), non_neg_integer()) ::
          ExOss.UploadCredential.t()
  def upload_credential(
        %Client{cdn_upload: true, cdn: %CDN{endpoint: endpoint}} = client,
        bucket,
        res_key,
        expires_in
      )
      when is_binary(endpoint) do
    CDNService.upload_credential(client, bucket, res_key, expires_in)
  end

  def upload_credential(client, bucket, res_key, expires_in) do
    client
    |> attach_upload_endpoint(bucket)
    |> Storage.upload_credential(bucket, res_key, expires_in)
  end

  @doc """
  Generates zip index content for mkzip operations.
  """
  @spec mkzip_index_content(Client.t(), list(%{access_address: binary(), alias_name: binary()})) ::
          binary()
  def mkzip_index_content(_client, items) do
    Storage.mkzip_index_content(items)
  end

  @doc """
  Generates a public (unsigned) URL using the download endpoint.

  If CDN is enabled, uses the CDN endpoint; otherwise uses the
  storage endpoint.
  """
  @spec public_url(Client.t(), binary(), binary()) :: binary()
  def public_url(client, bucket, res_key) do
    client
    |> attach_download_endpoint(bucket)
    |> Utils.public_url(bucket, res_key)
  end

  @doc false
  @spec attach_upload_endpoint(Client.t(), binary()) :: Client.t()
  def attach_upload_endpoint(
        %Client{cdn_upload: true, cdn: %CDN{endpoint: endpoint}} = client,
        _bucket
      )
      when is_binary(endpoint) do
    %{client | endpoint: endpoint}
  end

  def attach_upload_endpoint(client, bucket), do: do_attach_endpoint(client, bucket)

  @doc false
  @spec attach_download_endpoint(Client.t(), binary()) :: Client.t()
  def attach_download_endpoint(
        %Client{cdn_download: true, cdn: %CDN{endpoint: endpoint}} = client,
        _bucket
      )
      when is_binary(endpoint) do
    %{client | endpoint: endpoint}
  end

  def attach_download_endpoint(client, bucket), do: do_attach_endpoint(client, bucket)

  defp do_attach_endpoint(%Client{endpoint: endpoint} = client, _bucket)
       when is_binary(endpoint),
       do: client

  defp do_attach_endpoint(%Client{provider: :custom}, _bucket) do
    raise ArgumentError,
          "Custom provider requires an endpoint. Please configure the endpoint in the client."
  end

  defp do_attach_endpoint(client, bucket) do
    Storage.attach_endpoint(client, bucket)
  end
end
