defmodule Draught.CLI.Interactive.Inspection.Permissions do
  @moduledoc """
  Projects the active workspace and execution authority for terminal display.

  The projection identifies admitted risk classes and approval ownership
  without exposing adapter configuration or credentials.
  """

  alias Draught.CLI.Configuration
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Interactive.State
  alias Draught.CLI.Task.Risk
  alias Draught.Validation.Error

  @type approval :: :application_policy | :automatic | :effectful
  @type t :: %{
          required(:admitted_risks) => [Draught.Tool.Risk.t()],
          required(:approval) => approval(),
          required(:risk) => Configuration.risk(),
          required(:web_fetch) => boolean(),
          required(:web_search) => boolean(),
          required(:workspace) => String.t()
        }

  @doc "Returns the effective non-secret authority summary for one interactive session."
  @spec build(State.t(), Configuration.t(), Dependencies.t()) ::
          {:ok, t()} | {:error, Error.t()}
  def build(%State{} = state, %Configuration{} = configuration, %Dependencies{} = dependencies) do
    with {:ok, {admitted_risks, _policy}} <- Risk.resolve(configuration.risk) do
      {:ok,
       %{
         admitted_risks: admitted_risks,
         approval: approval(configuration.risk, dependencies.task.approval),
         risk: configuration.risk,
         web_fetch: state.web,
         web_search: state.web_search,
         workspace: state.workspace
       }}
    end
  end

  defp approval(_risk, {_module, _configuration}) do
    :application_policy
  end

  defp approval(:ask, nil) do
    :effectful
  end

  defp approval(risk, nil) when risk in [:allow, :deny] do
    :automatic
  end
end
