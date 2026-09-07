defmodule Draught.CLI.Task.Preparation.Builder.Assembly do
  @moduledoc """
  Assembles validated task components into one immutable preparation.
  """

  alias Draught.CLI.Task.Preparation
  alias Draught.CLI.Task.Preparation.Limits
  alias Draught.CLI.Task.Preparation.Messages
  alias Draught.CLI.Task.Preparation.Tools
  alias Draught.CLI.Task.Provider.Selection
  alias Draught.Execution.Runner.Configuration
  alias Draught.Session.Settings
  alias Draught.Validation.Error

  @doc "Builds a preparation after web and provider-mode policy validation."
  @spec build(term(), Selection.t(), String.t(), map(), :complete | :stream) ::
          Error.result(Preparation.t())
  def build(prompt, selection, workspace, attributes, provider_mode) do
    with {:ok, limits} <- Limits.new(attributes),
         {:ok, {registry, context}} <- Tools.prepare(attributes, workspace),
         {:ok, request} <-
           Messages.request(prompt, selection, instruction(attributes), history(attributes)),
         {:ok, runner} <- runner(selection, registry, context, limits, provider_mode) do
      {:ok, preparation(selection, request, runner, attributes)}
    end
  end

  defp preparation(selection, request, runner, attributes) do
    %Preparation{
      capabilities: selection.capabilities,
      request: request,
      runner: runner,
      session_options: [
        journal: Map.get(attributes, :journal, false),
        turn_timeout_ms: Settings.default_turn_timeout_ms()
      ]
    }
  end

  defp instruction(attributes) do
    Map.get(attributes, :system_prompt, Preparation.system_prompt())
  end

  defp history(attributes) do
    Map.get(attributes, :history, [])
  end

  defp runner(selection, registry, context, limits, provider_mode) do
    Configuration.new(
      provider: selection.adapter,
      provider_mode: provider_mode,
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
