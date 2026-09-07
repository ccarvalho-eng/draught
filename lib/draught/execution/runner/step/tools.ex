defmodule Draught.Execution.Runner.Step.Tools do
  @moduledoc false

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
    with {:ok, messages} <-
           ToolExecution.run(configuration, state.iteration, State.pending_calls(state)) do
      Transition.accept_tools(state, messages)
    end
  end
end
