defmodule ExOss.RunnerTest do
  use ExUnit.Case, async: true

  alias ExOss.Client.CDN
  alias ExOss.Client.Client
  alias ExOss.Runner

  @bucket_name "test-bucket"

  describe "attach_upload_endpoint/2" do
    test "returns client unchanged when endpoint is already set" do
      client = %Client{
        provider: :custom,
        access_key_id: "test",
        secret_access_key: "test",
        endpoint: "https://minio.example.com:9000"
      }

      result = Runner.attach_upload_endpoint(client, @bucket_name)
      assert %Client{endpoint: "https://minio.example.com:9000"} = result
    end

    test "returns client with endpoint set from aws provider" do
      client = %Client{
        provider: :aws,
        access_key_id: "test",
        secret_access_key: "test",
        region: "us-east-1",
        endpoint: nil
      }

      result = Runner.attach_upload_endpoint(client, @bucket_name)
      assert %Client{endpoint: "https://#{@bucket_name}.s3.us-east-1.amazonaws.com"} = result
    end

    test "returns client with endpoint set from qiniu s3 provider" do
      client = %Client{
        provider: :qiniu,
        access_key_id: "test",
        secret_access_key: "test",
        region: "cn-east-1",
        endpoint: nil
      }

      result = Runner.attach_upload_endpoint(client, @bucket_name)
      assert %Client{endpoint: "https://#{@bucket_name}.s3.cn-east-1.qiniucs.com"} = result
    end

    test "uses cdn endpoint when cdn_upload is enabled" do
      client = %Client{
        provider: :custom,
        access_key_id: "test",
        secret_access_key: "test",
        endpoint: nil,
        cdn_upload: true,
        cdn: %CDN{
          endpoint: "https://upload-cdn.example.com",
          provider: :cloudfront,
          module: ExOss.CDN.CloudFront
        }
      }

      result = Runner.attach_upload_endpoint(client, @bucket_name)
      assert %Client{endpoint: "https://upload-cdn.example.com"} = result
    end

    test "falls back to storage endpoint when cdn_upload is disabled" do
      client = %Client{
        provider: :aws,
        access_key_id: "test",
        secret_access_key: "test",
        region: "us-east-1",
        endpoint: nil,
        cdn_upload: false,
        cdn: %CDN{
          endpoint: "https://upload-cdn.example.com",
          provider: :cloudfront,
          module: ExOss.CDN.CloudFront
        }
      }

      result = Runner.attach_upload_endpoint(client, @bucket_name)
      assert %Client{endpoint: "https://#{@bucket_name}.s3.us-east-1.amazonaws.com"} = result
    end

    test "falls back to storage endpoint when cdn config is missing" do
      client = %Client{
        provider: :aws,
        access_key_id: "test",
        secret_access_key: "test",
        region: "us-east-1",
        endpoint: nil,
        cdn_upload: true,
        cdn: nil
      }

      result = Runner.attach_upload_endpoint(client, @bucket_name)
      assert %Client{endpoint: "https://#{@bucket_name}.s3.us-east-1.amazonaws.com"} = result
    end

    test "raises for custom provider without endpoint when cdn upload is disabled" do
      client = %Client{
        provider: :custom,
        access_key_id: "test",
        secret_access_key: "test",
        endpoint: nil,
        cdn_upload: false
      }

      assert_raise ArgumentError,
                   ~r/Custom provider requires an endpoint/,
                   fn -> Runner.attach_upload_endpoint(client, @bucket_name) end
    end
  end

  describe "attach_download_endpoint/2" do
    test "returns client unchanged when endpoint is already set" do
      client = %Client{
        provider: :custom,
        access_key_id: "test",
        secret_access_key: "test",
        endpoint: "https://minio.example.com:9000"
      }

      result = Runner.attach_download_endpoint(client, @bucket_name)
      assert %Client{endpoint: "https://minio.example.com:9000"} = result
    end

    test "returns client with endpoint set from aws provider" do
      client = %Client{
        provider: :aws,
        access_key_id: "test",
        secret_access_key: "test",
        region: "us-east-1",
        endpoint: nil
      }

      result = Runner.attach_download_endpoint(client, @bucket_name)
      assert %Client{endpoint: "https://#{@bucket_name}.s3.us-east-1.amazonaws.com"} = result
    end

    test "uses cdn endpoint when cdn_download is enabled" do
      client = %Client{
        provider: :custom,
        access_key_id: "test",
        secret_access_key: "test",
        endpoint: nil,
        cdn_download: true,
        cdn: %CDN{
          endpoint: "https://download-cdn.example.com",
          provider: :qiniu,
          module: ExOss.CDN.Qiniu
        }
      }

      result = Runner.attach_download_endpoint(client, @bucket_name)
      assert %Client{endpoint: "https://download-cdn.example.com"} = result
    end

    test "falls back to storage endpoint when cdn_download is disabled" do
      client = %Client{
        provider: :aws,
        access_key_id: "test",
        secret_access_key: "test",
        region: "us-east-1",
        endpoint: nil,
        cdn_download: false,
        cdn: %CDN{
          endpoint: "https://download-cdn.example.com",
          provider: :qiniu,
          module: ExOss.CDN.Qiniu
        }
      }

      result = Runner.attach_download_endpoint(client, @bucket_name)
      assert %Client{endpoint: "https://#{@bucket_name}.s3.us-east-1.amazonaws.com"} = result
    end

    test "falls back to storage endpoint when cdn config is missing" do
      client = %Client{
        provider: :aws,
        access_key_id: "test",
        secret_access_key: "test",
        region: "us-east-1",
        endpoint: nil,
        cdn_download: true,
        cdn: nil
      }

      result = Runner.attach_download_endpoint(client, @bucket_name)
      assert %Client{endpoint: "https://#{@bucket_name}.s3.us-east-1.amazonaws.com"} = result
    end

    test "raises for custom provider without endpoint when cdn download is disabled" do
      client = %Client{
        provider: :custom,
        access_key_id: "test",
        secret_access_key: "test",
        endpoint: nil,
        cdn_download: false
      }

      assert_raise ArgumentError,
                   ~r/Custom provider requires an endpoint/,
                   fn -> Runner.attach_download_endpoint(client, @bucket_name) end
    end
  end

  describe "public_url/3" do
    test "builds virtual-hosted style url for aws" do
      client = %Client{
        provider: :aws,
        access_key_id: "test",
        secret_access_key: "test",
        region: "us-east-1",
        bucket_addressing: :virtual
      }

      result = Runner.public_url(client, "bucket", "folder/file.txt")
      assert String.ends_with?(result, "bucket.s3.us-east-1.amazonaws.com/folder/file.txt")
    end

    test "builds path style url for custom" do
      client = %Client{
        provider: :custom,
        access_key_id: "test",
        secret_access_key: "test",
        endpoint: "https://minio.example.com:9000",
        bucket_addressing: :path
      }

      result = Runner.public_url(client, "bucket", "folder/file.txt")
      assert result == "https://minio.example.com:9000/bucket/folder/file.txt"
    end
  end

  describe "Client.new/1" do
    test "creates client with provider and cdn" do
      client =
        ExOss.Client.new(
          provider: :aws,
          access_key_id: "ak",
          secret_access_key: "sk",
          region: "us-west-2",
          cdn: [
            provider: :cloudfront,
            endpoint: "https://cdn.example.com",
            aws_key_id: "key-id",
            aws_private_key: "private-key"
          ]
        )

      assert client.provider == :aws
      assert client.region == "us-west-2"
      assert client.cdn.provider == :cloudfront
      assert client.cdn.module == ExOss.CDN.CloudFront
      assert client.cdn.endpoint == "https://cdn.example.com"
    end

    test "creates qiniu cdn client with module resolved" do
      client =
        ExOss.Client.new(
          provider: :custom,
          endpoint: "http://localhost:9000",
          bucket_addressing: :path,
          access_key_id: "minioadmin",
          secret_access_key: "minioadmin",
          cdn: [
            provider: :qiniu,
            endpoint: "https://cdn.example.com"
          ]
        )

      assert client.cdn.provider == :qiniu
      assert client.cdn.module == ExOss.CDN.Qiniu
    end

    test "creates client without cdn" do
      client =
        ExOss.Client.new(
          provider: :custom,
          endpoint: "http://localhost:9000",
          access_key_id: "ak",
          secret_access_key: "sk"
        )

      assert client.cdn == nil
    end

    test "redacts secrets in inspect" do
      client =
        ExOss.Client.new(
          provider: :aws,
          access_key_id: "my-secret-key",
          secret_access_key: "my-secret-secret"
        )

      inspected = inspect(client)
      assert String.contains?(inspected, "**REDACTED**")
      refute String.contains?(inspected, "my-secret-key")
    end
  end
end
