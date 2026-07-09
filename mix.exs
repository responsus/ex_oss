defmodule ExOss.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/responsus/ex_oss"

  def project do
    [
      app: :ex_oss,
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "ExOss",
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:ex_aws_s3, "~> 2.0"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "getting-started",
      source_url: @source_url,
      extras: [
        "guides/getting-started.md",
        "guides/aws-s3.md",
        "guides/s3-compatible.md",
        "guides/cdn-cloudfront.md",
        "guides/cdn-qiniu.md",
        "guides/file-transfer.md"
      ],
      groups_for_extras: [
        Guides: ~r/guides\/.*/
      ],
      groups_for_modules: [
        Core: [
          ExOss,
          ExOss.Client,
          ExOss.UploadCredential
        ],
        Configuration: [
          ExOss.Client.Client,
          ExOss.Client.CDN
        ],
        Storage: [
          ExOss.Storage,
          ExOss.StorageTask
        ],
        CDN: [
          ExOss.CDN,
          ExOss.CDN.Behaviour,
          ExOss.CDN.CloudFront,
          ExOss.CDN.Qiniu,
          ExOss.CDN.Qiniu.Auth,
          ExOss.CDN.Qiniu.PutPolicy
        ],
        Utilities: [
          ExOss.Utils,
          ExOss.LocalZipper
        ]
      ]
    ]
  end
end
