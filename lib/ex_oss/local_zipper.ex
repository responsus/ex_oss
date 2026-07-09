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
  @max_retries 3

  @type download_result :: {:ok, binary()} | :error
  @type zip_entry :: {charlist(), binary()}
  @type zip_list_result :: {:ok, [zip_entry()]} | :error

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
    with {:ok, body} <- download(index_path),
         {:ok, zip_file_list} <- build_zip_file_list(body),
         {:ok, content} <- compress(zip_file_list) do
      {:ok, content}
    else
      :error -> {:error, :gen_file_error}
    end
  end

  @spec build_zip_file_list(binary()) :: zip_list_result()
  defp build_zip_file_list(body) do
    body
    |> String.split("\n")
    |> Enum.reduce_while({:ok, []}, fn text, {:ok, acc} ->
      case String.trim(text) do
        "" ->
          {:cont, {:ok, acc}}

        "/url/" <> rest ->
          with {url_parts, [alias_name_encoded]} <-
                 String.split(rest, "/alias/", parts: :infinity) |> Enum.split(-1),
               {:ok, alias_name_binary} <- Base.url_decode64(alias_name_encoded),
               url_encoded = Enum.join(url_parts, "/alias/"),
               {:ok, url} <- Base.url_decode64(url_encoded),
               {:ok, content} <- download(url) do
            {:cont, {:ok, [{String.to_charlist(alias_name_binary), content} | acc]}}
          else
            _ -> {:halt, :error}
          end
      end
    end)
  end

  @spec compress([zip_entry()]) :: download_result()
  defp compress(zip_file_list) do
    path = DateTime.utc_now() |> DateTime.to_iso8601() |> String.to_charlist()

    case :zip.zip(path, zip_file_list, [:memory]) do
      {:ok, {_path, content}} -> {:ok, content}
      _ -> :error
    end
  end

  @spec download(binary()) :: download_result()
  defp download(url, retry_time \\ 0)

  defp download(_url, @max_retries), do: :error

  defp download(url, retry_time) do
    case Req.get(url, receive_timeout: @request_timeout) do
      {:ok, %Req.Response{status: code, body: body}}
      when is_integer(code) and code >= 200 and code <= 299 ->
        {:ok, body}

      _ ->
        download(url, retry_time + 1)
    end
  end
end
