# File Transfer

ExOss supports file transfer operations via `ExOss.StorageTask` structs
and the `run/1` macro function (or `ExOss.Runner.run/2`).

## StorageTask

An `ExOss.StorageTask` struct has `source`, `target`, and `opts` fields.

### Location Types

| Type | Format | Description |
|------|--------|-------------|
| Cloud | `{:cloud, bucket, key}` | Object in cloud storage |
| Remote URL | `{:remote, url}` | Download from a URL |
| Local file | `{:file, path}` | Upload from filesystem |
| Content | `{:content, binary}` | In-memory binary |

## Operations

### Upload from Local File

```elixir
MyApp.Storage.run(%ExOss.StorageTask{
  source: {:file, "/path/to/photo.jpg"},
  target: {:cloud, "bucket", "photos/photo.jpg"}
})
# => {:ok, "photos/photo.jpg"}
```

### Upload from Content

```elixir
MyApp.Storage.run(%ExOss.StorageTask{
  source: {:content, "Hello, World!"},
  target: {:cloud, "bucket", "hello.txt"}
})
# => {:ok, "hello.txt"}
```

### Upload from Remote URL

```elixir
MyApp.Storage.run(%ExOss.StorageTask{
  source: {:remote, "https://example.com/photo.jpg"},
  target: {:cloud, "bucket", "photos/photo.jpg"}
})
# => {:ok, "photos/photo.jpg"}
```

The remote content is downloaded via `Req.get/2` and then uploaded to
S3. The response's `Content-Type` header is used for the upload.

### Cloud-to-Cloud Copy

```elixir
MyApp.Storage.run(%ExOss.StorageTask{
  source: {:cloud, "source-bucket", "file.jpg"},
  target: {:cloud, "target-bucket", "copies/file.jpg"}
})
# => {:ok, "copies/file.jpg"}
```

This uses S3's `put_object_copy` (server-side copy).

### Delete Immediately

```elixir
MyApp.Storage.run(%ExOss.StorageTask{
  source: {:cloud, "bucket", "file.jpg"},
  target: nil
})
# => {:ok, nil}
```

### Delete After N Days (Delayed Delete)

```elixir
MyApp.Storage.run(%ExOss.StorageTask{
  source: {:cloud, "bucket", "file.jpg"},
  target: nil,
  opts: [days: 30]
})
# => {:ok, nil}
```

This adds a `delete_after_days` tag to the object. A lifecycle rule must
be configured on the bucket to actually expire tagged objects.

## Content-Type Detection

For `{:file, path}` and `{:content, binary}` sources, ExOss automatically
detects the content type using `MIME.from_path/1`. To override:

```elixir
MyApp.Storage.run(%ExOss.StorageTask{
  source: {:content, binary_data},
  target: {:cloud, "bucket", "file.dat"},
  opts: [content_type: "application/x-custom"]
})
```

## Error Handling

All operations return `{:ok, result}` or `{:error, reason}`:

```elixir
case MyApp.Storage.run(task) do
  {:ok, res_key} -> IO.puts("Uploaded to #{res_key}")
  {:error, reason} -> IO.puts("Failed: #{reason}")
end
```

## Using with Explicit Client

For multi-client scenarios:

```elixir
client = ExOss.Client.new(provider: :aws, ...)
ExOss.Runner.run(client, %ExOss.StorageTask{...})
```