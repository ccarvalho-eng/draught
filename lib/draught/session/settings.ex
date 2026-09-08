defmodule Draught.Session.Settings do
  @moduledoc """
  Validated immutable settings for one supervised session.
  """

  alias Draught.Execution.Runner.Configuration
  alias Draught.Session.Settings.Builder
  alias Draught.Session.Settings.Lifecycle
  alias Draught.Validation.Error

  @default_turn_timeout_ms 600_000

  @enforce_keys [:id, :journal, :lifecycle, :runner, :turn_timeout_ms]
  defstruct [:id, :journal, :lifecycle, :runner, :turn_timeout_ms]

  @type journal :: {module(), term()} | nil
  @type t :: %__MODULE__{
          id: String.t(),
          journal: journal(),
          lifecycle: Lifecycle.t(),
          runner: Configuration.t(),
          turn_timeout_ms: pos_integer() | :infinity
        }

  @doc "Builds session settings and reserves event-sink ownership for the session."
  @spec new(term(), term(), keyword() | map()) :: Error.result(t())
  def new(identifier, runner_configuration, options \\ []) do
    Builder.new(identifier, runner_configuration, options)
  end

  @doc false
  @spec default_turn_timeout_ms() :: pos_integer()
  def default_turn_timeout_ms do
    @default_turn_timeout_ms
  end

  @doc "Returns the stable module identifier for the configured provider adapter."
  @spec provider_name(t()) :: String.t()
  def provider_name(%__MODULE__{runner: %Configuration{provider: {module, _configuration}}}) do
    Atom.to_string(module)
  end
end
