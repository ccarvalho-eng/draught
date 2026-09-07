defmodule Draught.Session.Settings do
  @moduledoc """
  Validated immutable settings for one supervised session.
  """

  alias Draught.Execution.Runner.Configuration
  alias Draught.Session.Identifier
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @maximum_turn_timeout_ms 3_600_000

  @enforce_keys [:id, :runner, :turn_timeout_ms]
  defstruct [:id, :runner, :turn_timeout_ms]

  @type t :: %__MODULE__{
          id: String.t(),
          runner: Configuration.t(),
          turn_timeout_ms: pos_integer()
        }

  @doc "Builds session settings and reserves event-sink ownership for the session."
  @spec new(term(), term(), keyword() | map()) :: Error.result(t())
  def new(identifier, runner_configuration, options \\ []) do
    with {:ok, normalized} <- Attributes.normalize(options, [:turn_timeout_ms]),
         {:ok, id} <- Identifier.new(identifier),
         {:ok, runner} <- runner(runner_configuration),
         {:ok, turn_timeout_ms} <- timeout(normalized) do
      {:ok, %__MODULE__{id: id, runner: runner, turn_timeout_ms: turn_timeout_ms}}
    end
  end

  defp runner(attributes) do
    with {:ok, normalized} <- runner_attributes(attributes) do
      normalized
      |> Map.put(:sink, &discard/1)
      |> Configuration.new()
    end
  end

  defp runner_attributes(%Configuration{} = configuration) do
    {:ok, Map.from_struct(configuration)}
  end

  defp runner_attributes(attributes) when is_map(attributes) do
    {:ok, attributes}
  end

  defp runner_attributes(attributes) when is_list(attributes) do
    attributes
    |> Keyword.keyword?()
    |> keyword_attributes(attributes)
  end

  defp runner_attributes(_attributes) do
    Error.single([:runner], :invalid_type, "must be a runner configuration")
  end

  defp keyword_attributes(true, attributes) do
    {:ok, Map.new(attributes)}
  end

  defp keyword_attributes(false, _attributes) do
    Error.single([:runner], :invalid_type, "must be a runner configuration")
  end

  defp timeout(attributes) do
    value = Map.get(attributes, :turn_timeout_ms, 600_000)
    Value.positive_integer_at_most(value, @maximum_turn_timeout_ms, [:turn_timeout_ms])
  end

  defp discard(_event) do
    :ok
  end
end
