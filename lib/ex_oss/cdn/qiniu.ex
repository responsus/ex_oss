defmodule ExOss.CDN.Qiniu do
  @moduledoc """
  Qiniu CDN adapter.

  Implements `ExOss.CDN.Behaviour` to generate signed URLs for Qiniu's
  CDN service. This module is entirely self-contained — it does not
  depend on the `qiniu` hex package.

  ## Download URL Signing

  Qiniu CDN download URLs are signed with HMAC-SHA1 over the full URL
  (including a `e` deadline parameter), producing a `token` query
  parameter of the form `{access_key}:{signature}`.

  ## Upload Credentials

  Upload credentials use a Qiniu [PutPolicy](ExOss.CDN.Qiniu.PutPolicy.html)
  encoded as URL-safe Base64 JSON, signed with HMAC-SHA1 to produce an
  `uptoken` of the form `{access_key}:{signature}:{encoded_policy}`.

  ## Configuration

      config :my_app, MyApp.Storage,
        cdn: [
          provider: :qiniu,
          endpoint: "https://cdn.example.com"
        ]

  Credentials (`access_key_id` / `secret_access_key`) are taken from the
  client's storage credentials, not from a separate CDN key configuration.
  """

  @behaviour ExOss.CDN.Behaviour

  alias ExOss.Client.Client
  alias ExOss.Client.CDN
  alias ExOss.UploadCredential

  alias __MODULE__.{Auth, PutPolicy}

  @impl true
  @spec authorize_download_url(Client.t(), binary(), binary(), non_neg_integer(), keyword()) ::
          binary()
  def authorize_download_url(%Client{} = client, _bucket, res_key, expires_in, opts) do
    url = Auth.authorize_download_url(client, res_key, expires_in)

    if att_name = opts[:att_name] do
      url <> "&attname=" <> URI.encode_www_form(att_name)
    else
      url
    end
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
    uptoken =
      bucket
      |> PutPolicy.build(expires_in, force_save_key: true, save_key: res_key)
      |> then(&Auth.generate_uptoken(client, &1))

    %UploadCredential{
      uptoken: uptoken,
      presigned_url: nil,
      res_key: res_key,
      endpoint: endpoint
    }
  end
end
