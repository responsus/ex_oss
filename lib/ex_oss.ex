defmodule ExOss do
  @moduledoc """
  A unified S3-compatible object storage library with multi-CDN support.

  Supports AWS S3, Qiniu S3, and any S3-compatible service (MinIO, DigitalOcean Spaces,
  Cloudflare R2, etc.) with optional CDN integration (CloudFront, Qiniu CDN).

  ## Quick Start

      # 1. Define a storage module
      defmodule MyApp.Storage do
        use ExOss, otp_app: :my_app
      end

      # 2. Add configuration
      config :my_app, MyApp.Storage,
        provider: :aws,
        access_key_id: "your-access-key",
        secret_access_key: "your-secret-key",
        region: "us-east-1"

      # 3. Use it
      MyApp.Storage.upload_credential("bucket", "path/file.jpg", 3600)
      MyApp.Storage.authorize_download_url("bucket", "path/file.jpg", 3600)

  ## Multiple Clients

  Define separate modules for different storage providers:

      defmodule MyApp.AWSStorage do
        use ExOss, otp_app: :my_app
      end

      defmodule MyApp.MinIOStorage do
        use ExOss, otp_app: :my_app
      end

      config :my_app, MyApp.AWSStorage, provider: :aws, access_key_id: "...", ...
      config :my_app, MyApp.MinIOStorage,
        provider: :custom,
        endpoint: "http://localhost:9000",
        bucket_addressing: :path,
        access_key_id: "minioadmin",
        secret_access_key: "minioadmin"

  Or build clients programmatically:

      aws = ExOss.Client.new(provider: :aws, access_key_id: "...", ...)
      minio = ExOss.Client.new(provider: :custom, endpoint: "...", ...)

      ExOss.Runner.upload_credential(aws, "bucket", "key")
      ExOss.Runner.public_url(minio, "bucket", "key")

  ## CDN Configuration

      config :my_app, MyApp.Storage,
        provider: :aws,
        access_key_id: "...",
        secret_access_key: "...",
        cdn: [
          provider: :cloudfront,
          endpoint: "https://d123456789.cloudfront.net",
          aws_key_id: "K2XXXXXXXXXXXXX",
          aws_private_key: "-----BEGIN RSA PRIVATE KEY-----\\n..."
        ]
  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      app = Keyword.fetch!(opts, :otp_app)

      defp client do
        storage_config()
        |> Keyword.merge(unquote(opts))
        |> ExOss.Client.new()
      end

      defp storage_config do
        Application.fetch_env!(unquote(app), __MODULE__)
      end

      @doc """
      Retrieves metadata for a file.

      Returns `{:ok, %{file_size: integer, mime_type: string}}` or `{:error, :no_metadata}`.
      """
      def metadata(bucket, res_key) do
        ExOss.Runner.metadata(client(), bucket, res_key)
      end

      @doc """
      Generates a signed download URL.

      Options:
        * `:att_name` - Download filename for Content-Disposition header
      """
      def authorize_download_url(bucket, res_key, expires_in \\ 3600, opts \\ []) do
        ExOss.Runner.authorize_download_url(client(), bucket, res_key, expires_in, opts)
      end

      @doc """
      Generates upload credentials. Returns an `ExOss.UploadCredential` struct.
      """
      def upload_credential(bucket, res_key, expires_in \\ 3600) do
        ExOss.Runner.upload_credential(client(), bucket, res_key, expires_in)
      end

      @doc """
      Executes a storage task (upload, copy, delete, etc.).
      """
      def run(task) do
        ExOss.Runner.run(client(), task)
      end

      @doc """
      Generates index content for mkzip operations.
      """
      def mkzip_index_content(items) do
        ExOss.Runner.mkzip_index_content(client(), items)
      end

      @doc """
      Generates a public (unsigned) URL.
      """
      def public_url(bucket, res_key) do
        ExOss.Runner.public_url(client(), bucket, res_key)
      end
    end
  end
end
