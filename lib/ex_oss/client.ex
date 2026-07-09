defmodule ExOss.Client do
  @moduledoc """
  Client builder for runtime configuration.

  Use `new/1` to create a client, or `new/2` to merge options into an existing client.

  ## Example

      client = ExOss.Client.new(
        provider: :aws,
        access_key_id: "...",
        secret_access_key: "...",
        bucket: "my-bucket"
      )

      # Merge options
      other = ExOss.Client.new(client, bucket: "other-bucket")

  See `ExOss.Client.Client` for all available options.
  """

  alias ExOss.Client.CDN
  alias ExOss.Client.Client

  @type t :: Client.t()

  @doc """
  Creates a new client with the given options.
  """
  @spec new(keyword()) :: t()
  def new(opts) when is_list(opts) do
    opts |> Keyword.fetch!(:provider) |> Client.validate_provider!()

    cdn =
      if opts[:cdn] do
        opts[:cdn] |> Keyword.fetch!(:provider) |> CDN.validate_provider!()

        cdn_opts = opts[:cdn]
        provider = Keyword.fetch!(cdn_opts, :provider)
        module = cdn_module(provider)

        CDN
        |> struct(cdn_opts)
        |> Map.put(:module, module)
      end

    Client
    |> struct(opts)
    |> Map.put(:cdn, cdn)
  end

  @doc """
  Creates a new client by merging options into an existing client.

  Note: `provider` cannot be overridden.
  """
  @spec new(t(), keyword()) :: t()
  def new(%Client{cdn: cdn} = base, overrides) when is_list(overrides) do
    {cdn_overrides, client_overrides} =
      overrides |> Keyword.drop([:provider]) |> Keyword.pop(:cdn, [])

    cdn =
      cond do
        is_nil(cdn) and cdn_overrides == [] ->
          nil

        cdn_overrides == [] ->
          cdn

        is_nil(cdn) ->
          cdn_overrides |> Keyword.fetch!(:provider) |> CDN.validate_provider!()
          struct(CDN, cdn_overrides)

        true ->
          struct(cdn, cdn_overrides)
      end

    cdn = resolve_cdn_module(cdn)

    base
    |> struct(client_overrides)
    |> Map.put(:cdn, cdn)
  end

  defp cdn_module(:cloudfront), do: ExOss.CDN.CloudFront
  defp cdn_module(:qiniu), do: ExOss.CDN.Qiniu

  defp resolve_cdn_module(nil), do: nil

  defp resolve_cdn_module(%CDN{provider: provider} = cdn) do
    %{cdn | module: cdn_module(provider)}
  end
end
