defmodule ExOss.LocalZipper do
  @moduledoc """
  Local zip generation for S3-compatible storage services that lack
  cloud-side zip capabilities.

  This module downloads multiple files referenced by a zip index (produced
  by `ExOss.Storage.mkzip_index_content/1`), zips them in memory using
  `:zip.zip/3`, and returns the binary content. The resulting zip can then
  be uploaded to the storage backend via a `ExOss.StorageTask`.
  """

  @request_timeout 30_000

  @doc """
  Downloads all files referenced in the index and returns the zip binary.

  The `index_path` is the raw text returned by `ExOss.Storage.mkzip_index_content/1`.
  Each line encodes a URL and an alias name, both Base64 url-safe encoded:

      /url/{base64(url)}/alias/{base64(alias_name)}

  ## Examples

      index = ExOss.Storage.mkzip_index_content([
        %{access_address: "https://s3.example.com/img1.jpg", alias_name: "img1.jpg"}
      ])

      {:ok, zip_binary} = ExOss.LocalZipper.zip(index)

  Returns `{:ok, binary}` on success, or `{:error, :gen_file_error}` on failure.
  """
  @spec zip(binary()) :: {:ok, binary()} | {:error, :gen_file_error}
  def zip(index_path) do
    zip_file_list =
      index_path
      |> do_download!()
      |> parse_items_to_zip_file_list()

    useless_zip_file_path = DateTime.utc_now() |> DateTime.to_iso8601() |> Path.expand()

    case :zip.zip(useless_zip_file_path, zip_file_list, [:memory]) do
      {:ok, {_zip_file_path, content}} -> {:ok, content}
      _ -> {:error, :gen_file_error}
    end
  end

  @doc false
  @spec parse_items_to_zip_file_list(binary()) :: [{charlist(), binary()}]
  def parse_items_to_zip_file_list(body) do
    body
    |> String.split("\n")
    |> Enum.reduce([], fn text, acc ->
      case String.trim(text) do
        "" ->
          acc

        "/url/" <> text ->
          {url_parts, [alias_name]} =
            String.split(text, "/alias/", parts: :infinity) |> Enum.split(-1)

          alias_name = alias_name |> Base.url_decode64!() |> String.to_charlist()
          content = url_parts |> Enum.join("/alias/") |> Base.url_decode64!() |> do_download!()

          [{alias_name, content} | acc]
      end
    end)
  end

  defp do_download!(url, retry_time \\ 0)

  defp do_download!(_url, retry_time) when retry_time == 2 do
    raise RuntimeError, "Download file error!"
  end

  defp do_download!(url, retry_time) do
    case Req.get(url, receive_timeout: @request_timeout) do
      {:ok, %Req.Response{status: code, body: body}} when code >= 200 and code <= 299 -> body
      _ -> do_download!(url, retry_time + 1)
    end
  end
end
