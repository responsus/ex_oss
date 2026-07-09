defmodule ExOss.CDN.Qiniu.PutPolicy do
  @moduledoc """
  PutPolicy struct for uploading. And you have to specify right `scope`
  and `deadline` to let uploading work.

  See http://developer.qiniu.com/docs/v6/api/reference/security/put-policy.html
  """

  alias ExOss.Utils

  defstruct scope: nil,
            is_prefixal_scope: nil,
            deadline: nil,
            insert_only: nil,
            save_key: nil,
            force_save_key: nil,
            end_user: nil,
            return_url: nil,
            return_body: nil,
            callback_url: nil,
            callback_host: nil,
            callback_body: nil,
            callback_body_type: nil,
            callback_fetch_key: nil,
            persistent_ops: nil,
            persistent_notify_url: nil,
            persistent_pipeline: nil,
            fsize_min: nil,
            fsize_limit: nil,
            detect_mime: nil,
            mime_limit: nil,
            checksum: nil,
            file_type: nil

  @type t :: %__MODULE__{
          scope: String.t(),
          is_prefixal_scope: integer | nil,
          deadline: integer,
          insert_only: integer | nil,
          save_key: String.t() | nil,
          force_save_key: boolean | nil,
          end_user: String.t() | nil,
          return_url: String.t() | nil,
          return_body: String.t() | nil,
          callback_url: String.t() | nil,
          callback_host: String.t() | nil,
          callback_body: String.t() | nil,
          callback_body_type: String.t() | nil,
          callback_fetch_key: integer | nil,
          persistent_ops: String.t() | nil,
          persistent_notify_url: String.t() | nil,
          persistent_pipeline: String.t() | nil,
          fsize_min: integer | nil,
          fsize_limit: integer | nil,
          detect_mime: integer | nil,
          mime_limit: String.t() | nil,
          checksum: String.t() | nil,
          file_type: integer | nil
        }

  @default_expires_in 3600

  @doc """
  A better way to build PutPolicy, which can calculate deadline for you
  from expires_in(seconds) and can accpet the options. See build/2, build/3.

  ## Examples

      iex> ExOss.CDN.Qiniu.PutPolicy.build("scope")
      %ExOss.CDN.Qiniu.PutPolicy{scope: "scope", deadline: NOW_TIME + 3600}
  """
  @spec build(String.t()) :: t
  def build(scope) do
    build(scope, @default_expires_in, [])
  end

  @doc """
  build/2

  ## Examples

      iex> ExOss.CDN.Qiniu.PutPolicy.build("scope", 4000)
      %ExOss.CDN.Qiniu.PutPolicy{scope: "scope", deadline: NOW_TIME + 4000}

      iex> ExOss.CDN.Qiniu.PutPolicy.build("scope", insert_only: 1)
      %ExOss.CDN.Qiniu.PutPolicy{scope: "scope", deadline: NOW_TIME + 3600, insert_only: 1}
  """
  @spec build(String.t(), Integer.t() | Keyword.t()) :: t
  def build(scope, expires_in_or_options)

  def build(scope, expires_in) when is_integer(expires_in) and expires_in > 0 do
    build(scope, expires_in, [])
  end

  def build(scope, opts) when is_list(opts) do
    build(scope, @default_expires_in, opts)
  end

  @doc """
  build/3

  ## Examples

      iex> ExOss.CDN.Qiniu.PutPolicy.build("scope", 4000, insert_only: 1)
      %ExOss.CDN.Qiniu.PutPolicy{scope: "scope", deadline: NOW_TIME + 4000, insert_only: 1}

      # scope and deadline in options won't be used for override
      iex> ExOss.CDN.Qiniu.PutPolicy.build("scope", 4000, scope: "other_scope")
      %ExOss.CDN.Qiniu.PutPolicy{scope: "scope", deadline: NOW_TIME + 4000}
  """
  @spec build(String.t(), Integer.t(), Keyword.t()) :: t
  def build(scope, expires_in, opts)
      when is_integer(expires_in) and
             expires_in > 0 and is_list(opts) do
    deadline = Utils.deadline_unix(expires_in)
    struct(__MODULE__, Keyword.merge(opts, scope: scope, deadline: deadline))
  end

  @doc """
  Change put_policy to json string expect the `nil` values, whose keys are camelCase.

  ## Examples

      iex> policy = %ExOss.CDN.Qiniu.PutPolicy{scope: "scope", deadline: 1427990400, return_body: "body"}
      iex> ExOss.CDN.Qiniu.PutPolicy.to_json(policy)
      ~s({"deadline":1427990400,"returnBody":"body","scope":"scope"})
  """
  @spec to_json(t()) :: String.t()
  def to_json(%__MODULE__{} = policy) do
    policy
    |> Map.from_struct()
    |> Enum.filter(fn {_, v} -> v != nil end)
    |> Enum.map(fn {k, v} -> {Utils.camelize(k), v} end)
    |> Enum.into(%{})
    |> Utils.json_codec().encode!()
  end

  @doc """
  Change put_policy to json string and encode it with url safe

  ## Examples

      iex> policy = %ExOss.CDN.Qiniu.PutPolicy{scope: "scope"}
      iex> ExOss.CDN.Qiniu.PutPolicy.encoded_json(policy)
      "eyJzY29wZSI6InNjb3BlIn0="
  """
  @spec encoded_json(t()) :: String.t()
  def encoded_json(%__MODULE__{} = policy) do
    policy |> to_json() |> Base.url_encode64()
  end
end
