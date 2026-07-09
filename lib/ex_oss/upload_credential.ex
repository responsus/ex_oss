defmodule ExOss.UploadCredential do
  @moduledoc """
  Upload credential struct returned by `upload_credential/3`.

  ## Fields

  | Field | Type | Description |
  |-------|------|-------------|
  | `uptoken` | `String.t()` \| `nil` | Qiniu CDN upload token (nil for S3/CloudFront) |
  | `presigned_url` | `String.t()` \| `nil` | S3 presigned URL or CloudFront signed URL |
  | `res_key` | `String.t()` | Resource key (file path) |
  | `endpoint` | `String.t()` | Upload endpoint |

  ## S3 Upload

  Use `presigned_url` with a PUT request:

      credential = MyApp.Storage.upload_credential("bucket", "path/file.jpg", 3600)
      Req.put!(credential.presigned_url, body: file_content)

  ## Qiniu CDN Upload

  Use `uptoken` with Qiniu's form upload API:

      credential = MyApp.Storage.upload_credential("bucket", "path/file.jpg", 3600)
      # POST to credential.endpoint with token and file
  """

  defstruct [:uptoken, :presigned_url, :res_key, :endpoint]

  @type t :: %__MODULE__{
          uptoken: String.t() | nil,
          presigned_url: String.t() | nil,
          res_key: String.t(),
          endpoint: String.t()
        }
end
