defmodule ExOss.CDN.Behaviour do
  @moduledoc """
  Behaviour that all CDN adapters must implement.

  Each CDN provider implements this behaviour to provide signed download
  URLs and upload credentials. The dispatcher (`ExOss.CDN`) calls the
  adapter module resolved from the client's `cdn.module` field.

  ## Implementing a New CDN Adapter

      defmodule MyApp.CDN.Aliyun do
        @behaviour ExOss.CDN.Behaviour

        @impl true
        def authorize_download_url(client, bucket, res_key, expires_in, opts) do
          # Generate a signed URL using Aliyun CDN's signing protocol
          ...
        end

        @impl true
        def upload_credential(client, bucket, res_key, expires_in) do
          %ExOss.UploadCredential{...}
        end
      end

  Then register the adapter in `ExOss.Client.cdn_module/1`.
  """

  alias ExOss.Client.Client
  alias ExOss.UploadCredential

  @doc """
  Generates a signed download URL for the given resource key.
  """
  @callback authorize_download_url(
              client :: Client.t(),
              bucket :: binary(),
              res_key :: binary(),
              expires_in :: non_neg_integer(),
              opts :: keyword()
            ) ::
              binary()

  @doc """
  Generates upload credentials for the given resource key.
  """
  @callback upload_credential(
              client :: Client.t(),
              bucket :: binary(),
              res_key :: binary(),
              expires_in :: non_neg_integer()
            ) ::
              UploadCredential.t()
end
