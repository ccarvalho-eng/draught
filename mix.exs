defmodule Draught.MixProject do
  use Mix.Project

  @version "0.1.0-dev"
  @source_url "https://github.com/ccarvalho-eng/draught"
  @description "Provider-neutral coding-agent runtime and CLI for Elixir and the BEAM."

  def project do
    [
      app: :draught,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      description: @description,
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),
      package: package(),
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls, summary: [threshold: 90]],
      dialyzer: [
        plt_add_apps: [:mix, :ex_unit],
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Draught.Application, []}
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.json": :test,
        quality: :test,
        precommit: :test,
        ci: :test
      ]
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      files:
        ~w(lib docs .formatter.exs mix.exs mix.lock README* CHANGELOG* LICENSE* CONTRIBUTING* SECURITY*),
      links: %{
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md",
        "GitHub" => @source_url
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: [
        "README.md",
        "docs/architecture.md",
        "docs/providers/ollama.md",
        "CHANGELOG.md",
        "CONTRIBUTING.md",
        "SECURITY.md"
      ],
      groups_for_extras: [Guides: ["docs/architecture.md", "docs/providers/ollama.md"]]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:req, "~> 0.5"},
      {:telemetry, "~> 1.3"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.23.0", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.5", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: [:dev, :test], runtime: false},
      {:ex_ast, "== 0.12.0", only: [:dev, :test], runtime: false},
      {:ex_slop, "~> 0.4.2", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:reach, "~> 2.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"],
      quality: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --strict",
        "deps.unlock --check-unused",
        "deps.audit",
        "test"
      ],
      precommit: [
        "hex.build",
        "format --check-formatted",
        "compile --warnings-as-errors",
        "xref graph --format cycles --label compile-connected --fail-above 0",
        "deps.unlock --check-unused",
        "deps.audit",
        "credo --strict",
        "quality.structural",
        "test",
        "coveralls",
        "dialyzer",
        "doctor --raise",
        "docs"
      ],
      "quality.structural": ["quality.ex_dna", "quality.reach"],
      "quality.ex_dna": ["ex_dna --min-mass 40 --max-clones 0 --format console"],
      "quality.reach": ["reach.check --smells --strict"],
      ci: ["precommit"]
    ]
  end
end
