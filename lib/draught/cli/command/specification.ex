defmodule Draught.CLI.Command.Specification do
  @moduledoc """
  The immutable command, option, example, and input-limit specification.
  """

  @options [
    %{
      key: :provider,
      switch: "--provider",
      type: :string,
      value: "NAME",
      description: "Use a provider"
    },
    %{key: :model, switch: "--model", type: :string, value: "MODEL", description: "Use a model"},
    %{
      key: :base_url,
      switch: "--base-url",
      type: :string,
      value: "URL",
      description: "Use a provider URL"
    },
    %{
      key: :session,
      switch: "--session",
      type: :string,
      value: "ID",
      description: "Use a session identifier"
    },
    %{
      key: :resume,
      switch: "--resume",
      type: :string,
      value: "ID",
      description: "Resume a session"
    },
    %{
      key: :web,
      switch: "--[no-]web",
      type: :boolean,
      value: nil,
      description: "Enable or disable web access"
    },
    %{
      key: :output,
      switch: "--output",
      type: :string,
      value: "text|jsonl",
      description: "Select output format"
    },
    %{
      key: :color,
      switch: "--color",
      type: :string,
      value: "auto|always|never",
      description: "Select color behavior"
    },
    %{
      key: :diagnostics,
      switch: "--[no-]diagnostics",
      type: :boolean,
      value: nil,
      description: "Show diagnostics"
    },
    %{key: :help, switch: "--help", type: :boolean, value: nil, description: "Show help"},
    %{key: :version, switch: "--version", type: :boolean, value: nil, description: "Show version"}
  ]

  @commands [
    %{name: "interactive", command: :interactive, description: "Start an interactive session"},
    %{
      name: "doctor",
      command: :doctor,
      description: "Check local prerequisites and configuration"
    },
    %{name: "help", command: :help, description: "Show help"},
    %{name: "version", command: :version, description: "Show version"}
  ]

  @examples [
    "draught",
    "draught \"fix the tests\"",
    "draught doctor",
    "draught --provider ollama --model MODEL \"fix the tests\"",
    "draught --resume SESSION_ID \"continue this work\""
  ]

  @aliases [h: :help, v: :version]

  @limits %{
    arguments: 128,
    argument_bytes: 16_384,
    total_argument_bytes: 131_072,
    option_value_bytes: 2_048,
    prompt_bytes: 65_536
  }

  @type option :: %{
          key: atom(),
          switch: String.t(),
          type: :boolean | :string,
          value: String.t() | nil,
          description: String.t()
        }

  @type command :: %{name: String.t(), command: atom(), description: String.t()}

  @doc "Returns the ordered command option specification."
  @spec options() :: [option()]
  def options do
    @options
  end

  @doc "Returns the strict options accepted by `OptionParser`."
  @spec switches() :: keyword([:boolean | :string | :keep])
  def switches do
    Enum.map(@options, fn option -> {option.key, [option.type, :keep]} end)
  end

  @doc "Returns the closed short-option aliases."
  @spec aliases() :: keyword(atom())
  def aliases do
    @aliases
  end

  @doc "Returns the ordered named command specification."
  @spec commands() :: [command()]
  def commands do
    @commands
  end

  @doc "Returns copyable command examples."
  @spec examples() :: [String.t()]
  def examples do
    @examples
  end

  @doc "Returns the bounded raw-input limits enforced before parsing."
  @spec limits() :: %{required(atom()) => pos_integer()}
  def limits do
    @limits
  end
end
