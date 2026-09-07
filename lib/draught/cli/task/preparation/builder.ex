defmodule Draught.CLI.Task.Preparation.Builder do
  @moduledoc false

  alias Draught.CLI.Task.Preparation
  alias Draught.CLI.Task.Preparation.Limits
  alias Draught.CLI.Task.Preparation.Messages
  alias Draught.CLI.Task.Preparation.Tools
  alias Draught.CLI.Task.Provider.Selection
  alias Draught.Execution.Runner.Configuration
  alias Draught.Session.Settings
  alias Draught.Validation.Error

  @doc "Coordinates pure construction of one execution preparation."
  @spec build(term(), Selection.t(), String.t(), map()) :: Error.result(Preparation.t())
  def build(prompt, %Selection{} = selection, workspace, attributes) do
    with :ok <- web_disabled(attributes),
         {:ok, limits} <- Limits.new(attributes),
         {:ok, {registry, context}} <- Tools.prepare(attributes, workspace),
         {:ok, request} <- Messages.request(prompt, selection, instruction(attributes)),
         {:ok, runner} <- runner(selection, registry, context, limits) do
      {:ok,
       %Preparation{
         request: request,
         runner: runner,
         session_options: [
           journal: false,
           turn_timeout_ms: Settings.default_turn_timeout_ms()
         ]
       }}
    end
  end

  defp web_disabled(attributes) do
    case Map.get(attributes, :web, false) do
      false -> :ok
      true -> Error.single([:web], :invalid_value, "Web execution is not available yet")
      _value -> Error.single([:web], :invalid_type, "must be a boolean")
    end
  end

  defp instruction(attributes) do
    Map.get(attributes, :system_prompt, Preparation.system_prompt())
  end

  defp runner(selection, registry, context, limits) do
    Configuration.new(
      provider: selection.adapter,
      registry: registry,
      tool_context: context,
      limits: limits,
      sink: &discard/1
    )
  end

  defp discard(_event) do
    :ok
  end
end
