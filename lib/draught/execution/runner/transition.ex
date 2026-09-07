defmodule Draught.Execution.Runner.Transition do
  @moduledoc """
  Pure transitions for bounded provider and tool execution.
  """

  alias Draught.Execution.Runner.Failure
  alias Draught.Execution.Runner.State
  alias Draught.Execution.Runner.ToolResults
  alias Draught.Provider.Request
  alias Draught.Validation.Error

  @doc "Starts the next provider iteration or stops at a terminal condition."
  @spec next_request(State.t()) ::
          {:continue, State.t(), Request.t()} | {:halt, State.t()} | {:error, Error.t()}
  def next_request(%State{status: :ready} = state) do
    next_request_limit(state.iteration < state.limits.max_iterations, state)
  end

  def next_request(%State{status: status} = state) when status in [:completed, :failed] do
    {:halt, state}
  end

  def next_request(%State{}) do
    invalid_transition(:next_request)
  end

  @doc "Appends exactly one ordered tool-result message per pending call."
  @spec accept_tools(State.t(), [Draught.Conversation.Message.Tool.t()]) ::
          {:ok, State.t()} | {:error, Error.t()}
  def accept_tools(%State{status: :waiting_tools} = state, messages) do
    with {:ok, canonical} <- ToolResults.reconcile(state.pending_calls, messages) do
      {:ok,
       %State{
         state
         | messages: state.messages ++ canonical,
           pending_calls: [],
           status: :ready
       }}
    end
  end

  def accept_tools(%State{}, _messages) do
    invalid_transition(:accept_tools)
  end

  defp next_request_limit(true, state) do
    request = request_with_messages(state)
    updated = %{state | iteration: state.iteration + 1, status: :waiting_provider}
    {:continue, updated, request}
  end

  defp next_request_limit(false, state) do
    {:halt, fail(state, Failure.iteration_limit())}
  end

  defp request_with_messages(state) do
    {:ok, request} =
      Request.new(
        model: state.request.model,
        messages: state.messages,
        tools: state.request.tools,
        options: state.request.options
      )

    request
  end

  defp fail(state, error) do
    %{state | outcome: error, pending_calls: [], status: :failed}
  end

  defp invalid_transition(operation) do
    Error.single([:status], :invalid_relationship, "cannot #{operation} from the current state")
  end
end
