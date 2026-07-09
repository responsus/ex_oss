defmodule ExOssTest do
  use ExUnit.Case

  alias ExOss.Storage

  describe "Storage.mkzip_index_content/1" do
    test "generates zip index with url and alias encoded" do
      result =
        Storage.mkzip_index_content([
          %{access_address: "https://example.com/1.jpg", alias_name: "img1.jpg"},
          %{access_address: "https://example.com/2.png", alias_name: "img2.png"}
        ])

      lines = String.split(result, "\n")
      assert length(lines) == 2

      [line1, line2] = lines
      assert String.starts_with?(line1, "/url/")
      assert String.contains?(line1, "/alias/")

      # decode to verify
      assert String.contains?(line1, Base.url_encode64("img1.jpg"))
      assert String.contains?(line2, Base.url_encode64("img2.png"))
    end

    test "returns empty string for empty list" do
      assert Storage.mkzip_index_content([]) == ""
    end
  end

  describe "StorageTask" do
    test "builds_struct with defaults" do
      task = %ExOss.StorageTask{source: {:content, "abc"}, target: {:cloud, "bucket", "key"}}
      assert task.opts == []
      assert task.policy == []
    end

    test "supports delayed delete opts" do
      task = %ExOss.StorageTask{
        source: {:cloud, "bucket", "key"},
        target: nil,
        opts: [days: 7]
      }

      assert task.opts[:days] == 7
    end
  end
end
