defmodule Draught.CLI.Interactive.Command.Help do
  @moduledoc """
  Renders available and planned interactive commands and input forms.
  """

  alias Draught.CLI.Interactive.Command.Catalog
  alias Draught.CLI.Interactive.Command.Catalog.Entry

  @doc "Renders the command index with explicit availability labels."
  @spec render() :: iodata()
  def render do
    [
      "Available commands:\n",
      lines(Catalog.active()),
      "\nInput controls:\n",
      "  Enter           Submit prompt\n",
      "  Ctrl+J          Insert newline\n",
      "  Alt+Enter       Insert newline\n",
      "  Tab             Complete a command\n",
      "\nUnavailable commands:\n",
      lines(Catalog.reserved()),
      "\nUnavailable input forms:\n",
      "  @QUERY         Reserved for workspace file selection\n",
      "  !COMMAND       Reserved for confined direct commands\n"
    ]
  end

  defp lines(entries) do
    Enum.map(entries, &line/1)
  end

  defp line(%Entry{} = entry) do
    padding = String.duplicate(" ", max(2, 16 - String.length(entry.usage)))
    ["  ", entry.usage, padding, entry.description, "\n"]
  end
end
