defmodule Draught.Session.Settings.Builder do
  @moduledoc false

  alias Draught.Execution.Runner.Configuration
  alias Draught.Session.Identifier
  alias Draught.Session.Settings
  alias Draught.Session.Settings.Journal
  alias Draught.Session.Settings.Lifecycle
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @maximum_turn_timeout_ms 3_600_000

  @doc "Builds validated immutable session settings."
  @spec new(term(), term(), keyword() | map()) :: Error.result(Settings.t())
  def new(identifier, runner_configuration, options) do
    with {:ok, normalized} <- normalize(options),
         {:ok, id} <- Identifier.new(identifier),
         {:ok, runner} <- runner(runner_configuration),
         {:ok, runtime} <- runtime(normalized, runner, id) do
      build(id, runner, runtime)
    end
  end

  defp build(id, runner, runtime) do
    {:ok,
     %Settings{
       id: id,
       journal: runtime.journal,
       lifecycle: runtime.lifecycle,
       runner: runner,
       turn_timeout_ms: runtime.turn_timeout_ms
     }}
  end

  defp normalize(options) do
    Attributes.normalize(options, [:journal, :lifecycle, :turn_timeout_ms])
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

  defp runtime(attributes, runner, id) do
    with {:ok, journal} <- Journal.build(attributes, runner.tool_context.workspace, id),
         {:ok, lifecycle} <- lifecycle(attributes),
         {:ok, turn_timeout_ms} <- timeout(attributes) do
      {:ok,
       %{
         journal: journal,
         lifecycle: lifecycle,
         turn_timeout_ms: turn_timeout_ms
       }}
    end
  end

  defp keyword_attributes(true, attributes) do
    {:ok, Map.new(attributes)}
  end

  defp keyword_attributes(false, _attributes) do
    Error.single([:runner], :invalid_type, "must be a runner configuration")
  end

  defp lifecycle(attributes) do
    attributes
    |> Map.get(:lifecycle, [])
    |> Lifecycle.new()
  end

  defp timeout(attributes) do
    value = Map.get(attributes, :turn_timeout_ms, Settings.default_turn_timeout_ms())
    Value.positive_integer_at_most(value, @maximum_turn_timeout_ms, [:turn_timeout_ms])
  end

  defp discard(_event) do
    :ok
  end
end
