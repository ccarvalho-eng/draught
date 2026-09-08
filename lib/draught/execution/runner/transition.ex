defmodule Draught.Execution.Runner.Transition do
  @moduledoc """
  Pure transitions for bounded provider and tool execution.
  """

  alias Draught.Error.Normalized
  alias Draught.Execution.Runner.Failure
  alias Draught.Execution.Runner.State
  alias Draught.Execution.Runner.ToolBatch.Progress
  alias Draught.Execution.Runner.ToolResults
  alias Draught.Provider.Request
  alias Draught.Tool.Registry
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

  @doc "Appends ordered results and refreshes read history when registry risks prove eligibility."
  @spec accept_tools(State.t(), [Draught.Conversation.Message.Tool.t()], Registry.t() | nil) ::
          {:ok, State.t()} | {:error, Error.t()}
  def accept_tools(state, messages, registry \\ nil)

  def accept_tools(%State{status: :waiting_tools} = state, messages, registry) do
    with {:ok, canonical} <- ToolResults.reconcile(state.pending_calls, messages) do
      {:ok,
       %State{
         state
         | messages: state.messages ++ canonical,
           pending_calls: [],
           seen_batches: Progress.refresh(state.seen_batches, canonical, registry),
           status: :ready
       }}
    end
  end

  def accept_tools(%State{}, _messages, _registry) do
    invalid_transition(:accept_tools)
  end

  @doc "Moves a nonterminal state to a canonical failed outcome."
  @spec fail(State.t(), Normalized.t()) :: {:ok, State.t()} | {:error, Error.t()}
  def fail(%State{status: status} = state, %Normalized{} = error)
      when status in [:ready, :waiting_provider, :waiting_tools] do
    canonical_result =
      error
      |> Map.from_struct()
      |> Normalized.new()

    with {:ok, canonical} <- canonical_result do
      {:ok, failed(state, canonical)}
    end
  end

  def fail(%State{}, %Normalized{}) do
    invalid_transition(:fail)
  end

  defp next_request_limit(true, state) do
    request = request_with_messages(state)
    updated = %{state | iteration: state.iteration + 1, status: :waiting_provider}
    {:continue, updated, request}
  end

  defp next_request_limit(false, state) do
    {:halt, failed(state, Failure.iteration_limit())}
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

  defp failed(state, error) do
    %{state | outcome: error, pending_calls: [], status: :failed}
  end

  defp invalid_transition(operation) do
    Error.single([:status], :invalid_relationship, "cannot #{operation} from the current state")
  end
end
