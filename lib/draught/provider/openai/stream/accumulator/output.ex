defmodule Draught.Provider.OpenAI.Stream.Accumulator.Output do
  @moduledoc "Constructs canonical nonterminal events from validated stream data."

  alias Draught.Event.Provider.Delta
  alias Draught.Event.Provider.ToolCall
  alias Draught.Provider.OpenAI.Protocol

  @doc "Builds ordered reasoning and text events for one provider delta."
  @spec deltas(Draught.Provider.OpenAI.Stream.Chunk.Delta.t()) ::
          {:ok, [Delta.t()]} | {:error, Draught.Error.Normalized.t()}
  def deltas(%Draught.Provider.OpenAI.Stream.Chunk.Delta{} = delta) do
    with {:ok, reasoning} <- optional_delta(:reasoning, delta.reasoning),
         {:ok, content} <- optional_delta(:text, delta.content) do
      {:ok, Enum.reject([reasoning, content], &is_nil/1)}
    end
  end

  @doc "Builds ordered canonical events for complete tool calls."
  @spec tool_calls([Draught.Tool.Call.t()]) ::
          {:ok, [ToolCall.t()]} | {:error, Draught.Error.Normalized.t()}
  def tool_calls(calls) do
    calls
    |> Enum.reduce_while({:ok, []}, &build_tool_call/2)
    |> reverse_events()
  end

  defp optional_delta(_kind, nil) do
    {:ok, nil}
  end

  defp optional_delta(_kind, "") do
    {:ok, nil}
  end

  defp optional_delta(kind, content) do
    [kind: kind, content: content]
    |> Delta.new()
    |> Protocol.canonical("invalid_stream_delta", "Provider stream delta is malformed")
  end

  defp build_tool_call(call, {:ok, events}) do
    case ToolCall.new(call: call) do
      {:ok, event} ->
        {:cont, {:ok, [event | events]}}

      {:error, error} ->
        result = Protocol.canonical({:error, error}, "invalid_tool_call", "Tool call is invalid")
        {:halt, result}
    end
  end

  defp reverse_events({:ok, events}) do
    {:ok, Enum.reverse(events)}
  end

  defp reverse_events({:error, _error} = result) do
    result
  end
end
