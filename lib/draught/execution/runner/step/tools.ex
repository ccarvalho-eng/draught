defmodule Draught.Execution.Runner.Step.Tools do
  @moduledoc """
  Performs one pending tool batch and applies its messages to runner state.

  The step preserves the runner's pending-call order and delegates state
  validation to the tool transition boundary.
  """

  alias Draught.Error.Normalized
  alias Draught.Execution.Runner.Configuration
  alias Draught.Execution.Runner.State
  alias Draught.Execution.Runner.ToolExecution
  alias Draught.Execution.Runner.Transition
  alias Draught.Validation.Error

  @doc "Executes and applies one pending tool-call batch."
  @spec run(Configuration.t(), State.t()) ::
          {:ok, State.t()} | {:error, Normalized.t() | Error.t()}
  def run(configuration, state) do
    with {:ok, messages} <- execute(configuration, state) do
      Transition.accept_tools(state, messages, configuration.registry)
    end
  end

  defp execute(configuration, state) do
    calls = State.pending_calls(state)

    case State.pending_tool_action(state) do
      :execute -> ToolExecution.run(configuration, state.iteration, calls)
      :reject_duplicate -> ToolExecution.reject_duplicate(configuration, state.iteration, calls)
    end
  end
end
