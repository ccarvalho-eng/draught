defmodule Draught.CLI.Task.Stream.Renderer.Text do
  @moduledoc """
  Renders safe projected CLI events as append-only human-readable text.
  """

  alias Draught.CLI.Task.Stream.Event

  @doc "Renders one projected event without cursor control or terminal queries."
  @spec render(Event.t()) :: {:ok, iodata()}
  def render(%Event{type: :text_delta, content: content}) do
    {:ok, content}
  end

  def render(%Event{type: :tool_call} = event) do
    {:ok, [prefix(event), "[tool] ", event.name, target(event), " requested\n"]}
  end

  def render(%Event{type: :tool_result} = event) do
    {:ok,
     [
       prefix(event),
       "[tool] ",
       event.name,
       " ",
       Atom.to_string(event.status),
       error_code(event.code),
       "\n"
     ]}
  end

  def render(%Event{type: :success, streamed: true} = event) do
    {:ok, [event.content || "", trailing_newline(event)]}
  end

  def render(%Event{type: :success, streamed: false, content: content}) do
    {:ok, [content, "\n"]}
  end

  def render(%Event{type: :failure} = event) do
    {:ok,
     [
       prefix(event),
       "Task failed (",
       event.code,
       "): ",
       event.message,
       "\n"
     ]}
  end

  defp prefix(%Event{prefix_newline: true}) do
    "\n"
  end

  defp prefix(%Event{}) do
    ""
  end

  defp error_code(nil) do
    ""
  end

  defp error_code(code) do
    [" (", code, ")"]
  end

  defp target(%Event{target: nil}) do
    ""
  end

  defp target(%Event{target: target}) do
    [" ", target]
  end

  defp trailing_newline(%Event{prefix_newline: true}) do
    "\n"
  end

  defp trailing_newline(%Event{}) do
    ""
  end
end
