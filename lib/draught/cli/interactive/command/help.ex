defmodule Draught.CLI.Interactive.Command.Help do
  @moduledoc """
  Renders the interactive command catalog and reserved input forms.
  """

  alias Draught.CLI.Interactive.Command.Catalog
  alias Draught.CLI.Interactive.Command.Catalog.Entry

  @doc "Renders the active and reserved interactive command index."
  @spec render() :: iodata()
  def render do
    [
      "Available commands:\n",
      lines(Catalog.active()),
      "\nReserved commands:\n",
      lines(Catalog.reserved()),
      "\nInput forms:\n",
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
