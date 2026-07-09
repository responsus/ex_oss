defmodule ExOss.CDNTest do
  use ExUnit.Case, async: true

  alias ExOss.CDN
  alias ExOss.Client.CDN, as: ClientCDN
  alias ExOss.Client.Client

  describe "CloudFront CDN flow" do
    test "authorize_download_url/5 signs cloudfront url" do
      client = %Client{
        provider: :custom,
        access_key_id: "ak",
        secret_access_key: "sk",
        cdn_download: true,
        cdn: %ClientCDN{
          provider: :cloudfront,
          module: ExOss.CDN.CloudFront,
          endpoint: "https://d111111abcdef8.cloudfront.net",
          aws_key_id: "K123456789",
          aws_private_key: cloudfront_private_key_pem()
        }
      }

      url =
        CDN.authorize_download_url(client, "bucket", "folder/a b.txt", 120, att_name: "out.txt")

      assert String.starts_with?(url, "https://d111111abcdef8.cloudfront.net/folder/a%20b.txt?")
      assert String.contains?(url, "response-content-disposition=")
      assert String.contains?(url, "Expires=")
      assert String.contains?(url, "Signature=")
      assert String.contains?(url, "Key-Pair-Id=K123456789")
      assert String.contains?(url, "Policy=")
    end

    test "upload_credential/4 uses cloudfront endpoint and signed url" do
      client = %Client{
        provider: :custom,
        access_key_id: "ak",
        secret_access_key: "sk",
        cdn_upload: true,
        cdn: %ClientCDN{
          provider: :cloudfront,
          module: ExOss.CDN.CloudFront,
          endpoint: "https://d111111abcdef8.cloudfront.net",
          aws_key_id: "K123456789",
          aws_private_key: cloudfront_private_key_pem()
        }
      }

      credential = CDN.upload_credential(client, "bucket", "folder/a.txt", 120)

      assert credential.endpoint == "https://d111111abcdef8.cloudfront.net"
      assert credential.uptoken == nil
      assert is_binary(credential.presigned_url)
      assert String.contains?(credential.presigned_url, "Key-Pair-Id=K123456789")
    end
  end

  describe "Qiniu CDN flow" do
    test "authorize_download_url/5 signs qiniu url with token" do
      client = %Client{
        provider: :custom,
        access_key_id: "qiniu_ak",
        secret_access_key: "qiniu_sk",
        cdn_download: true,
        cdn: %ClientCDN{
          provider: :qiniu,
          module: ExOss.CDN.Qiniu,
          endpoint: "https://cdn.example.com"
        }
      }

      url = CDN.authorize_download_url(client, "bucket", "a b.txt", 120, att_name: "out.txt")

      assert String.starts_with?(url, "https://cdn.example.com/a%20b.txt?")
      assert String.contains?(url, "e=")
      assert String.contains?(url, "token=qiniu_ak:")
      assert String.contains?(url, "&attname=out.txt")
    end

    test "upload_credential/4 uses qiniu cdn endpoint and uptoken" do
      client = %Client{
        provider: :custom,
        access_key_id: "qiniu_ak",
        secret_access_key: "qiniu_sk",
        cdn_upload: true,
        cdn: %ClientCDN{
          provider: :qiniu,
          module: ExOss.CDN.Qiniu,
          endpoint: "https://cdn.example.com"
        }
      }

      credential = CDN.upload_credential(client, "bucket", "folder/a.txt", 120)

      assert credential.endpoint == "https://cdn.example.com"
      assert is_binary(credential.uptoken)
      assert String.starts_with?(credential.uptoken, "qiniu_ak:")
      assert credential.presigned_url == nil
    end
  end

  defp cloudfront_private_key_pem do
    private_key = :public_key.generate_key({:rsa, 1024, 65_537})

    :RSAPrivateKey
    |> :public_key.pem_entry_encode(private_key)
    |> then(&[&1])
    |> :public_key.pem_encode()
  end
end
