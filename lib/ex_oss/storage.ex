defmodule ExOss.Storage do
  @moduledoc """
  S3-based storage implementation for AWS S3 and S3-compatible services.

  Supports three provider modes:

    * `:aws` — Standard AWS S3 (endpoint auto-constructed as `s3.{region}.amazonaws.com`)
    * `:qiniu` — Qiniu S3-compatible API (endpoint auto-constructed as `s3.{region}.qiniucs.com`)
    * `:custom` — Any S3-compatible service (MinIO, DigitalOcean Spaces, Cloudflare R2, etc.)
      Requires an explicit `endpoint` to be configured.

  All storage operations go through `ex_aws_s3`.

  ## File Transfer Operations

  Use `run/2` with an `ExOss.StorageTask` struct to perform uploads,
  copies, deletes, and content uploads:

      # Upload from local file
      ExOss.Storage.run(client, %ExOss.StorageTask{
        source: {:file, "/path/to/file.jpg"},
        target: {:cloud, "bucket", "uploads/file.jpg"}
      })

      # Upload from remote URL
      ExOss.Storage.run(client, %ExOss.StorageTask{
        source: {:remote, "https://example.com/file.jpg"},
        target: {:cloud, "bucket", "uploads/file.jpg"}
      })

      # Cloud-to-cloud copy
      ExOss.Storage.run(client, %ExOss.StorageTask{
        source: {:cloud, "source-bucket", "file.jpg"},
        target: {:cloud, "target-bucket", "copies/file.jpg"}
      })

      # Delete immediately
      ExOss.Storage.run(client, %ExOss.StorageTask{
        source: {:cloud, "bucket", "file.jpg"},
        target: nil
      })

      # Delete after N days (via lifecycle tags)
      ExOss.Storage.run(client, %ExOss.StorageTask{
        source: {:cloud, "bucket", "file.jpg"},
        target: nil,
        opts: [days: 30]
      })

  ## Presigned URLs

  Generate temporary, direct-access URLs without CDN:

      # Download URL (presigned GET)
      ExOss.Storage.authorize_download_url(client, "bucket", "file.jpg", 3600)

      # Upload URL (presigned PUT)
      ExOss.Storage.upload_credential(client, "bucket", "file.jpg", 3600)

  When a CDN is configured on the client, use `ExOss.Runner` instead —
  it automatically routes to the CDN adapter when `cdn_download` /
  `cdn_upload` are enabled.
  """

  alias ExOss.Client.Client
  alias ExOss.StorageTask
  alias ExOss.Utils

  @doc """
  Generates zip index content for local zip operations.

  Each item must contain `:access_address` (the source URL) and
  `:alias_name` (the filename inside the zip). Both are Base64
  url-safe encoded into the index format expected by
  `ExOss.LocalZipper.zip/1`.

  ## Examples

      iex> ExOss.Storage.mkzip_index_content([
      ...>   %{access_address: "https://s3.example.com/1.jpg", alias_name: "img1.jpg"}
      ...> ])
      "/url/aHR0cHM6Ly9zMy5leGFtcGxlLmNvbS8xLmpwZw==/alias/aW1nMS5qcGc="
  """
  @spec mkzip_index_content(list(%{access_address: binary(), alias_name: binary()})) :: binary()
  def mkzip_index_content(items) do
    items
    |> Enum.map(fn %{access_address: address, alias_name: alias_name} ->
      "/url/#{Base.url_encode64(address)}/alias/#{Base.url_encode64(alias_name)}"
    end)
    |> Enum.join("\n")
  end

  def run(
        client,
        %StorageTask{
          source: {:cloud, from_bucket, from_key},
          target: {:cloud, target_bucket, target_key}
        } = task
      ) do
    target_bucket
    |> ExAws.S3.put_object_copy(target_key, from_bucket, from_key)
    |> aws_request(client, task)
    |> case do
      {:ok, %{status_code: status}} when status in 200..299 -> {:ok, target_key}
      {:ok, response} -> {:error, inspect(response)}
      {:error, _err} = err -> err
    end
  end

  def run(
        client,
        %StorageTask{source: {:remote, url}, target: {:cloud, bucket, res_key}, opts: opts} = task
      ) do
    case Req.get(url, raw: true) do
      {:ok, %Req.Response{status: 200, body: body} = response} ->
        opts = ensure_content_type_from_remote(opts, response)

        bucket
        |> ExAws.S3.put_object(res_key, body, opts)
        |> aws_request(client, task)
        |> case do
          {:ok, %{status_code: status}} when status in 200..299 -> {:ok, res_key}
          {:ok, response} -> {:error, inspect(response)}
          {:error, _err} = err -> err
        end

      {:ok, %Req.Response{body: body}} ->
        {:error, body}

      {:error, error} ->
        {:error, error}
    end
  end

  def run(client, %StorageTask{source: {:cloud, bucket, res_key}, target: nil, opts: opts} = task) do
    case opts[:days] do
      nil ->
        bucket
        |> ExAws.S3.delete_object(res_key)
        |> aws_request(client, task)
        |> case do
          {:ok, %{status_code: status}} when status in 200..299 -> {:ok, nil}
          {:ok, response} -> {:error, inspect(response)}
          {:error, _err} = err -> err
        end

      days ->
        bucket
        |> ExAws.S3.put_object_tagging(res_key, %{
          tags: [%{key: "delete_after_days", value: days}]
        })
        |> aws_request(client, task)
        |> case do
          {:ok, %{status_code: status}} when status in 200..299 -> {:ok, nil}
          {:ok, response} -> {:error, inspect(response)}
          {:error, _err} = err -> err
        end
    end
  end

  def run(
        client,
        %StorageTask{source: {:file, path}, target: {:cloud, bucket, res_key}, opts: opts} = task
      ) do
    opts = ensure_content_type(opts, res_key)

    path
    |> ExAws.S3.Upload.stream_file()
    |> ExAws.S3.upload(bucket, res_key, opts)
    |> aws_request(client, task)
    |> case do
      {:ok, %{status_code: status}} when status in 200..299 -> {:ok, res_key}
      {:ok, response} -> {:error, inspect(response)}
      {:error, _err} = err -> err
    end
  end

  def run(
        client,
        %StorageTask{source: {:content, content}, target: {:cloud, bucket, res_key}, opts: opts} =
          task
      ) do
    opts = ensure_content_type(opts, res_key)

    bucket
    |> ExAws.S3.put_object(res_key, content, opts)
    |> aws_request(client, task)
    |> case do
      {:ok, %{status_code: status}} when status in 200..299 -> {:ok, res_key}
      {:ok, response} -> {:error, inspect(response)}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Generates an S3 presigned upload URL for the given resource key.

  Returns an `ExOss.UploadCredential` struct with the `presigned_url` field
  set to a PUT presigned URL. The `uptoken` field is `nil` for S3.

  ## Examples

      iex> cred = ExOss.Storage.upload_credential(client, "bucket", "file.jpg", 3600)
      iex> cred.presigned_url
      "https://bucket.s3.us-east-1.amazonaws.com/file.jpg?X-Amz-..."
      iex> cred.uptoken
      nil
  """
  @spec upload_credential(Client.t(), binary(), binary(), non_neg_integer()) ::
          ExOss.UploadCredential.t()
  def upload_credential(%Client{} = client, bucket, res_key, expires_in) do
    config = aws_config(client, bucket)
    datetime = :calendar.universal_time()
    target_url = Utils.public_url(client, bucket, res_key)

    {:ok, presigned_url} =
      ExAws.Auth.presigned_url(:put, target_url, :s3, datetime, config, expires_in, [], nil, [])

    %ExOss.UploadCredential{
      uptoken: nil,
      presigned_url: presigned_url,
      res_key: res_key,
      endpoint: client.endpoint
    }
  end

  @doc """
  Generates an S3 presigned download URL for the given resource key.

  ## Options

    * `:query_params` — additional query parameters to include in the signed URL
    * `:headers` — headers to include in the signature
    * `:att_name` — (not used by S3, handled by CDN adapters)

  ## Examples

      iex> ExOss.Storage.authorize_download_url(client, "bucket", "file.jpg", 3600, [])
      "https://bucket.s3.us-east-1.amazonaws.com/file.jpg?X-Amz-..."
  """
  @spec authorize_download_url(Client.t(), binary(), binary(), non_neg_integer(), keyword()) ::
          binary()
  def authorize_download_url(%Client{} = client, bucket, res_key, expire_in, opts) do
    query_params = Keyword.get(opts, :query_params, [])
    headers = Keyword.get(opts, :headers, [])

    datetime = :calendar.universal_time()
    url = Utils.public_url(client, bucket, res_key)

    {:ok, presigned_url} =
      ExAws.Auth.presigned_url(
        :get,
        url,
        :s3,
        datetime,
        aws_config(client, bucket),
        expire_in,
        query_params,
        nil,
        headers
      )

    presigned_url
  end

  @doc """
  Resolves and sets the endpoint URL on the client based on the provider.

  For `:aws` and `:qiniu`, the endpoint is auto-constructed as
  `https://{bucket}.s3.{region}.amazonaws.com` (or `qiniucs.com`).

  For `:custom`, the endpoint must already be set on the client.
  """
  @spec attach_endpoint(Client.t(), binary()) :: Client.t()
  def attach_endpoint(%Client{provider: provider} = client, bucket)
      when provider in [:aws, :qiniu] do
    %{client | endpoint: "https://#{bucket}.#{host(client)}"}
  end

  def attach_endpoint(%Client{} = client, _bucket), do: client

  @doc """
  Retrieves metadata for a stored object via a HEAD request.

  Returns `{:ok, %{file_size: integer, mime_type: string}}` on success,
  or `{:error, :no_metadata}` if the object does not exist or is not
  accessible.
  """
  @spec metadata(Client.t(), binary(), binary()) ::
          {:ok, %{file_size: non_neg_integer(), mime_type: binary()}} | {:error, :no_metadata}
  def metadata(client, bucket, res_key) do
    bucket
    |> ExAws.S3.head_object(res_key)
    |> aws_request(client, bucket)
    |> case do
      {:ok, %{status_code: 200, headers: headers}} ->
        headers_map = Map.new(headers, fn {k, v} -> {String.downcase(k), v} end)

        {:ok,
         %{
           file_size: headers_map["content-length"] |> String.to_integer(),
           mime_type: headers_map["content-type"]
         }}

      _ ->
        {:error, :no_metadata}
    end
  end

  defp aws_request(operation, %Client{} = client, %StorageTask{} = task) do
    bucket = extract_bucket(task)
    aws_request(operation, client, bucket)
  end

  defp aws_request(operation, %Client{} = client, bucket) do
    config = aws_config(client, bucket)
    ExAws.Operation.perform(operation, config)
  end

  defp extract_bucket(%StorageTask{target: {:cloud, bucket, _}}), do: bucket
  defp extract_bucket(%StorageTask{source: {:cloud, bucket, _}}), do: bucket

  defp aws_config(%Client{provider: :aws} = client, bucket) do
    overrides = client |> attach_endpoint(bucket) |> client_config()
    ExAws.Config.new(:s3, Map.to_list(overrides))
  end

  defp aws_config(%Client{} = client, bucket) when is_binary(bucket) do
    overrides = client |> attach_endpoint(bucket) |> client_config()

    Map.merge(base_config(), overrides)
  end

  defp base_config do
    %{
      http_client: ExAws.Request.Hackney,
      json_codec: Utils.json_codec(),
      retries: [max_attempts: 10, base_backoff_in_ms: 10, max_backoff_in_ms: 10_000],
      normalize_path: true,
      require_imds_v2: false
    }
  end

  defp client_config(%Client{endpoint: endpoint} = client) do
    %URI{scheme: scheme, host: host, port: port} = URI.parse(endpoint)

    host =
      if client.bucket_addressing == :virtual do
        host(client) || host
      else
        host
      end

    %{}
    |> put_if(:access_key_id, client.access_key_id)
    |> put_if(:secret_access_key, client.secret_access_key)
    |> put_if(:region, client.region)
    |> put_if(:scheme, "#{scheme}://")
    |> put_if(:host, host)
    |> put_if(:port, port)
  end

  defp put_if(config, _key, nil), do: config
  defp put_if(config, key, value), do: Map.put(config, key, value)

  defp host(%Client{provider: :aws, region: region}), do: "s3.#{region}.amazonaws.com"
  defp host(%Client{provider: :qiniu, region: region}), do: "s3.#{region}.qiniucs.com"
  defp host(_), do: nil

  defp ensure_content_type(opts, res_key) do
    case Keyword.get(opts, :content_type) do
      nil ->
        case MIME.from_path(res_key) do
          "application/octet-stream" -> opts
          mime_type -> Keyword.put(opts, :content_type, mime_type)
        end

      _ ->
        opts
    end
  end

  defp ensure_content_type_from_remote(opts, response) do
    case Keyword.get(opts, :content_type) do
      nil ->
        case Req.Response.get_header(response, "content-type") do
          [content_type | _] -> Keyword.put(opts, :content_type, content_type)
          [] -> opts
        end

      _ ->
        opts
    end
  end
end
