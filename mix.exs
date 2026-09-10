defmodule Draught.MixProject do
  use Mix.Project

  @version "0.1.0-beta.7"
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
      escript: [main_module: Draught.CLI.EntryPoint],
      releases: releases(),
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
      mod: {application_module(Mix.target()), []}
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
        ~w(lib docs priv/builtin_skills .formatter.exs mix.exs mix.lock README* CHANGELOG* LICENSE* CONTRIBUTING* SECURITY*),
      links: %{
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md",
        "GitHub" => @source_url
      }
    ]
  end

  defp application_module(:cli) do
    Draught.CLI.Release.Application
  end

  defp application_module(_target) do
    Draught.Application
  end

  defp releases do
    [
      draught: [
        steps: [&validate_release_target/1, :assemble, &Burrito.wrap/1],
        burrito: [
          extra_steps: [
            fetch: [pre: [Draught.Distribution.Burrito.MuslRuntime]]
          ],
          targets: burrito_targets()
        ]
      ]
    ]
  end

  defp burrito_targets do
    runtime_archive = System.get_env("DRAUGHT_ERTS_ARCHIVE")
    musl_archive = System.get_env("DRAUGHT_MUSL_ARCHIVE")

    [
      macos_arm64: [os: :darwin, cpu: :aarch64, custom_erts: runtime_archive],
      macos_x86_64: [os: :darwin, cpu: :x86_64, custom_erts: runtime_archive],
      linux_arm64: [
        os: :linux,
        cpu: :aarch64,
        custom_erts: runtime_archive,
        musl_archive: musl_archive,
        musl_sha256: "6b558025200a5ed1308e2ce2675217afec71b6c5a9d561e52262ca948d59905e"
      ],
      linux_x86_64: [
        os: :linux,
        cpu: :x86_64,
        custom_erts: runtime_archive,
        musl_archive: musl_archive,
        musl_sha256: "71c35316aff45bbfd243d8eb9bfc4a58b6eb97cee09514cd2030e145b68107fb"
      ]
    ]
  end

  defp validate_release_target(release) do
    if Mix.target() != :cli do
      Mix.raise("Build the executable with MIX_TARGET=cli MIX_ENV=prod mix release draught")
    end

    release
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: [
        "README.md",
        {"docs/index.md", [filename: "guides", title: "Documentation"]},
        "docs/getting-started.md",
        "docs/cli.md",
        "docs/configuration.md",
        "docs/skills.md",
        "docs/distribution.md",
        "docs/architecture.md",
        "docs/conversation-interchange.md",
        "docs/runner.md",
        "docs/session-journals.md",
        "docs/sessions.md",
        "docs/telemetry.md",
        "docs/tools.md",
        "docs/web-access.md",
        "docs/workspace-confinement.md",
        "docs/providers/ollama.md",
        "CHANGELOG.md",
        "CONTRIBUTING.md",
        "SECURITY.md"
      ],
      groups_for_extras: [
        CLI: [
          "docs/getting-started.md",
          "docs/cli.md",
          "docs/configuration.md",
          "docs/skills.md",
          "docs/distribution.md"
        ],
        Guides: [
          "docs/architecture.md",
          "docs/conversation-interchange.md",
          "docs/runner.md",
          "docs/session-journals.md",
          "docs/sessions.md",
          "docs/telemetry.md",
          "docs/tools.md",
          "docs/web-access.md",
          "docs/workspace-confinement.md",
          "docs/providers/ollama.md"
        ]
      ]
    ]
  end

  defp deps do
    [
      {:burrito, "== 1.6.0"},
      {:jason, "~> 1.4"},
      {:mint, "~> 1.10"},
      {:owl, "~> 0.13.1"},
      {:req, "~> 0.5"},
      {:telemetry, "~> 1.3"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.23.0", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.5", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: [:dev, :test], runtime: false},
      {:ex_ast, "== 0.12.10", only: [:dev, :test], runtime: false},
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
