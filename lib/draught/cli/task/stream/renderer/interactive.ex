defmodule Draught.CLI.Task.Stream.Renderer.Interactive do
  @moduledoc """
  Separates assistant speech and tool activity in terminal conversation output.

  Assistant segments use spacing rather than speaker headings. Only the fixed
  tool label receives optional styling; piped text and JSONL use their
  existing renderers instead of this presentation boundary.
  """

  alias Draught.CLI.Task.Stream.Event
  alias Draught.CLI.Task.Stream.Renderer.Text
  alias Draught.CLI.UI
  alias Draught.CLI.UI.Theme

  @status_roles %{error: :error, success: :success}

  @doc "Renders safe conversation content and distinct, optionally styled tool activity."
  @spec render(Event.t(), boolean()) :: {:ok, iodata()}
  def render(%Event{type: :text_delta} = event, _styled?) do
    {:ok, [segment_spacing(event), event.content]}
  end

  def render(%Event{type: :tool_call} = event, styled?) do
    {:ok,
     [
       separator(event),
       "  ",
       UI.tool_label(styled?),
       ": ",
       event.name,
       target(event, styled?),
       " ",
       Theme.chardata("(requested)", :muted, styled?),
       "\n"
     ]}
  end

  def render(%Event{type: :tool_result} = event, styled?) do
    {:ok,
     [
       separator(event),
       "  ",
       UI.tool_label(styled?),
       ": ",
       event.name,
       " (",
       outcome(event, styled?),
       ")\n"
     ]}
  end

  def render(%Event{type: :success} = event, _styled?) do
    {:ok, rendered} = Text.render(event)
    {:ok, [segment_spacing(event), rendered]}
  end

  def render(%Event{type: :failure} = event, _styled?) do
    Text.render(event)
  end

  defp segment_spacing(%Event{heading: true} = event) do
    [separator(event), "\n"]
  end

  defp segment_spacing(%Event{}) do
    ""
  end

  defp separator(%Event{prefix_newline: true}) do
    "\n"
  end

  defp separator(%Event{}) do
    ""
  end

  defp error_code(nil) do
    ""
  end

  defp error_code(code) do
    [": ", code]
  end

  defp outcome(event, styled?) do
    content = [Atom.to_string(event.status), error_code(event.code)]
    role = Map.get(@status_roles, event.status, :muted)
    Theme.chardata(content, role, styled?)
  end

  defp target(%Event{target: nil}, _styled?) do
    ""
  end

  defp target(%Event{target: target}, styled?) do
    [" ", Theme.chardata(target, :path, styled?)]
  end
end
