defmodule ExOss.CDN do
  @moduledoc """
  CDN dispatcher that routes to the appropriate CDN adapter module
  based on the client's `cdn.module` configuration.

  This module is the single entry point for all CDN operations. It
  delegates to the module stored in `ExOss.Client.CDN.module`, which is
  resolved at client construction time from the `:provider` atom.

  ## Supported CDN Providers

    * `:cloudfront` — AWS CloudFront (see `ExOss.CDN.CloudFront`)
    * `:qiniu` — Qiniu CDN (see `ExOss.CDN.Qiniu`)

  ## Adding a New CDN Provider

  1. Create a module implementing `ExOss.CDN.Behaviour`
  2. Add a clause to `ExOss.Client.cdn_module/1` to map the provider atom
  3. Add the atom to `ExOss.Client.CDN.validate_provider!/1`
  """

  alias ExOss.Client.CDN, as: ClientCDN
  alias ExOss.Client.Client
  alias ExOss.UploadCredential

  @spec authorize_download_url(Client.t(), binary(), binary(), non_neg_integer(), keyword()) ::
          binary()
  def authorize_download_url(
        %Client{cdn: %ClientCDN{module: mod}} = client,
        bucket,
        res_key,
        expires_in,
        opts
      )
      when is_atom(mod) do
    mod.authorize_download_url(client, bucket, res_key, expires_in, opts)
  end

  @spec upload_credential(Client.t(), binary(), binary(), non_neg_integer()) ::
          UploadCredential.t()
  def upload_credential(
        %Client{cdn: %ClientCDN{module: mod}} = client,
        bucket,
        res_key,
        expires_in
      )
      when is_atom(mod) do
    mod.upload_credential(client, bucket, res_key, expires_in)
  end
end
