defmodule Draught.CLI.UI.Owl.InputArea do
  @moduledoc """
  Renders a bounded, open-sided input frame for ordinary terminal line editing.

  Rounded rails and optional command hints separate input from assistant output.
  No right-hand border or cursor repositioning interferes with wrapped input.
  Styling is reset before the terminal echoes any user text.
  """

  @maximum_width 96
  @hint " /help · /model "

  @doc "Renders one input boundary with explicit terminal width and styling."
  @spec render(:open | :close, pos_integer(), boolean()) :: iodata()
  def render(:open, width, styled?) when width >= 8 do
    [
      "\n",
      decorate(top(width), :light_black, styled?),
      "\n",
      decorate("│ ", :light_black, styled?),
      decorate("›", [:cyan, :bright], styled?),
      " "
    ]
  end

  def render(:open, 1, _styled?) do
    "\n>"
  end

  def render(:open, _width, _styled?) do
    "\n> "
  end

  def render(:close, width, styled?) when width >= 8 do
    [decorate(["╰", rule(width - 1)], :light_black, styled?), "\n\n"]
  end

  def render(:close, _width, _styled?) do
    "\n"
  end

  defp top(width) when width >= 32 do
    bounded_width = min(width, @maximum_width)
    ["╭─", @hint, rule(bounded_width - 2 - String.length(@hint))]
  end

  defp top(width) do
    ["╭", rule(width - 1)]
  end

  defp rule(width) do
    String.duplicate("─", min(width, @maximum_width - 1))
  end

  defp decorate(content, sequences, true) do
    IO.ANSI.format([sequences, content, :reset], true)
  end

  defp decorate(content, _sequences, false) do
    content
  end
end
