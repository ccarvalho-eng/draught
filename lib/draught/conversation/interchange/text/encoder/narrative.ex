defmodule Draught.Conversation.Interchange.Text.Encoder.Narrative do
  @moduledoc false

  alias Draught.Conversation.Content.Text
  alias Draught.Conversation.Document
  alias Draught.Conversation.Message.Assistant
  alias Draught.Conversation.Message.System
  alias Draught.Conversation.Message.Tool
  alias Draught.Conversation.Message.User

  @doc "Renders the non-authoritative human-readable conversation view."
  @spec render(Document.t()) :: String.t()
  def render(%Document{messages: messages}) do
    body =
      Enum.map_join(messages, "\n\n", &message/1)

    "# Conversation\n\n" <> body <> "\n"
  end

  defp message(%System{content: content}) do
    "## System\n\n" <> content.text
  end

  defp message(%User{content: content}) do
    "## User\n\n" <> content.text
  end

  defp message(%Assistant{content: [], tool_calls: []}) do
    "## Assistant\n\n[response filtered]"
  end

  defp message(%Assistant{} = assistant) do
    sections = [assistant_text(assistant.content), tool_calls(assistant.tool_calls)]

    "## Assistant\n\n" <> join_sections(sections)
  end

  defp message(%Tool{result: result}) do
    "## Tool result: `#{result.name}`\n\n" <>
      "Call: `#{result.call_id}`\n\nStatus: `#{result.status}`\n\n[tool result omitted]"
  end

  defp assistant_text(content) do
    content
    |> Enum.filter(&match?(%Text{}, &1))
    |> Enum.map_join("\n\n", & &1.text)
  end

  defp tool_calls([]) do
    ""
  end

  defp tool_calls(calls) do
    entries = Enum.map_join(calls, "\n", &"- `#{&1.name}` (`#{&1.id}`)")
    "### Tool calls\n\n" <> entries
  end

  defp join_sections(sections) do
    sections
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end
end
