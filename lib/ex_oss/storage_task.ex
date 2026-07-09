defmodule ExOss.StorageTask do
  @moduledoc """
  Storage task struct for file transfer operations.

  ## Location Types

    * `{:cloud, bucket, res_key}` - Cloud storage
    * `{:remote, url}` - Remote URL
    * `{:file, path}` - Local file
    * `{:content, binary}` - Raw content

  ## Examples

      # Upload from URL
      %StorageTask{source: {:remote, url}, target: {:cloud, bucket, key}}

      # Delete
      %StorageTask{source: {:cloud, bucket, key}, target: nil}

      # Delete after N days
      %StorageTask{source: {:cloud, bucket, key}, target: nil, opts: [days: 7]}
  """

  defstruct source: nil, target: nil, policy: [], opts: []

  @type object ::
          {:cloud, bucket :: binary, res_key :: binary}
          | {:remote, url :: binary}
          | {:file, path :: binary}
          | {:content, content :: binary}

  @type t :: %__MODULE__{
          source: object(),
          target: object() | nil,
          opts: keyword
        }
end
