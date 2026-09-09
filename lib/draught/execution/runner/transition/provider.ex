defmodule Draught.Execution.Runner.Transition.Provider do
  @moduledoc """
  Pure provider-result transitions for runner state.
  """

  alias Draught.Error.Normalized
  alias Draught.Execution.Runner.Failure
  alias Draught.Execution.Runner.State
  alias Draught.Execution.Runner.ToolBatch
  alias Draught.Provider.Response
  alias Draught.Validation.Error

  @doc "Applies one canonical provider result to waiting state."
  @spec accept(State.t(), {:ok, Response.t()} | {:error, Normalized.t()}) ::
          {:ok, State.t()} | {:error, Error.t()}
  def accept(%State{status: :waiting_provider} = state, {:ok, response}) do
    with {:ok, canonical} <- canonical_response(response) do
      accept_response(state, canonical)
    end
  end

  def accept(%State{status: :waiting_provider} = state, {:error, error}) do
    with {:ok, canonical} <- canonical_error(error) do
      {:ok, fail(state, canonical)}
    end
  end

  def accept(%State{}, _result) do
    invalid_transition()
  end

  defp accept_response(%State{} = state, %Response{message: %{tool_calls: []}} = response) do
    {:ok,
     %State{
       state
       | messages: Enum.concat(state.messages, [response.message]),
         outcome: response,
         status: :completed
     }}
  end

  defp accept_response(%State{} = state, %Response{message: %{tool_calls: calls}} = response) do
    key = ToolBatch.key(calls)
    seen? = MapSet.member?(state.seen_batches, key)
    rejected? = MapSet.member?(state.rejected_batches, key)
    accept_batch(seen?, rejected?, state, response, calls, key)
  end

  defp accept_batch(true, true, state, _response, _calls, _key) do
    {:ok, fail(state, Failure.duplicate_tool_batch())}
  end

  defp accept_batch(true, false, %State{} = state, response, calls, key) do
    {:ok,
     %State{
       state
       | messages: Enum.concat(state.messages, [response.message]),
         pending_calls: calls,
         pending_tool_action: :reject_duplicate,
         rejected_batches: MapSet.put(state.rejected_batches, key),
         status: :waiting_tools
     }}
  end

  defp accept_batch(false, _rejected, %State{} = state, response, calls, key) do
    {:ok,
     %State{
       state
       | messages: Enum.concat(state.messages, [response.message]),
         pending_calls: calls,
         pending_tool_action: :execute,
         seen_batches: MapSet.put(state.seen_batches, key),
         status: :waiting_tools
     }}
  end

  defp canonical_response(%Response{} = response) do
    response
    |> Map.from_struct()
    |> Response.new()
  end

  defp canonical_response(_response) do
    Error.single([:response], :invalid_type, "must be a provider response")
  end

  defp canonical_error(%Normalized{} = error) do
    error
    |> Map.from_struct()
    |> Normalized.new()
  end

  defp canonical_error(_error) do
    Error.single([:error], :invalid_type, "must be a normalized error")
  end

  defp fail(state, error) do
    %{state | outcome: error, pending_calls: [], pending_tool_action: nil, status: :failed}
  end

  defp invalid_transition do
    Error.single(
      [:status],
      :invalid_relationship,
      "cannot accept_provider from the current state"
    )
  end
end
