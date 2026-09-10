defmodule Draught.Provider.Ollama.Stream.Replay do
  @moduledoc """
  Replays validated canonical Ollama output after response classification.

  The provider facade validates every replayed event and owns terminal delivery.
  """

  alias Draught.Conversation.Content.Reasoning
  alias Draught.Conversation.Content.Text
  alias Draught.Conversation.Message.Assistant
  alias Draught.Event.Provider.Delta
  alias Draught.Event.Provider.ToolCall
  alias Draught.Provider.Response

  @doc "Emits canonical content and tool calls in retained response order."
  @spec emit(Response.t(), Draught.Provider.adapter_sink()) :: :ok
  def emit(%Response{message: %Assistant{} = message}, sink) when is_function(sink, 1) do
    with :ok <- emit_content(message.content, sink) do
      emit_calls(message.tool_calls, sink)
    end
  end

  defp emit_content([], _sink) do
    :ok
  end

  defp emit_content([%Text{text: text} | rest], sink) do
    with :ok <- sink.(%Delta{kind: :text, content: text}) do
      emit_content(rest, sink)
    end
  end

  defp emit_content([%Reasoning{text: text} | rest], sink) do
    with :ok <- sink.(%Delta{kind: :reasoning, content: text}) do
      emit_content(rest, sink)
    end
  end

  defp emit_calls([], _sink) do
    :ok
  end

  defp emit_calls([call | rest], sink) do
    with :ok <- sink.(%ToolCall{call: call}) do
      emit_calls(rest, sink)
    end
  end
end
