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
      "Available now:\n",
      lines(Catalog.active()),
      "\nPlanned commands (not available yet):\n",
      lines(Catalog.reserved()),
      "\nPlanned input forms (not available yet):\n",
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
