defmodule Draught.Provider.OpenAI.Execution.Stream.Reducer do
  @moduledoc """
  Reduces arbitrary transport chunks into SSE data and canonical events.
  """

  alias Draught.Error.Normalized
  alias Draught.Provider.OpenAI.Execution.Stream.State
  alias Draught.Provider.OpenAI.Stream.Accumulator
  alias Draught.Provider.OpenAI.Stream.SSE

  @doc "Consumes one transport chunk and synchronously emits accepted events."
  @spec reduce(binary(), State.t(), Draught.Provider.adapter_sink()) ::
          Draught.Provider.OpenAI.Transport.stream_action(State.t())
  def reduce(data, %State{} = state, sink) do
    case SSE.push(state.sse, data) do
      {:ok, sse, values} -> consume(values, %State{state | sse: sse}, sink)
      {:done, sse, values} -> consume(values, %State{state | sse: sse}, sink)
      {:error, %Normalized{} = error} -> halt(state, error)
    end
  end

  defp consume(values, state, sink) do
    result =
      Enum.reduce_while(values, {:ok, state}, fn value, {:ok, %State{} = current} ->
        case Accumulator.push(current.accumulator, value) do
          {:ok, accumulator, events} ->
            Enum.each(events, sink)
            {:cont, {:ok, %State{current | accumulator: accumulator}}}

          {:error, %Normalized{} = error} ->
            {:halt, {:error, %State{current | error: error}}}
        end
      end)

    consume_result(result)
  end

  defp consume_result({:ok, state}) do
    {:cont, state, State.output?(state)}
  end

  defp consume_result({:error, state}) do
    {:halt, state, State.output?(state)}
  end

  defp halt(%State{} = state, error) do
    failed = %State{state | error: error}
    {:halt, failed, State.output?(failed)}
  end
end
