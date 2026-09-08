defmodule Draught.CLI.UI.Owl.InputArea do
  @moduledoc """
  Renders a bounded, open-sided input frame for ordinary terminal line editing.

  The top rail keeps active model and workspace context beside help discovery.
  No right-hand border or cursor repositioning interferes with wrapped input,
  and styling is reset before the terminal echoes any user text.
  """

  alias Elixir.Owl.Data

  @maximum_width 96
  @hint "  /help "

  @doc "Renders one input boundary with explicit terminal width and styling."
  @spec render(:open | :close, String.t(), String.t(), pos_integer(), boolean()) :: iodata()
  def render(:open, model, workspace, width, styled?) when width >= 8 do
    [
      "\n",
      top(model, workspace, width, styled?),
      "\n",
      decorate("│ ", :light_black, styled?),
      decorate("›", [:cyan, :bright], styled?),
      " "
    ]
  end

  def render(:open, model, workspace, 1, styled?) do
    ["\n", narrow_context(model, workspace, 1, styled?), "\n>"]
  end

  def render(:open, model, workspace, width, styled?) do
    ["\n", narrow_context(model, workspace, width, styled?), "\n> "]
  end

  def render(:close, _model, _workspace, width, styled?) when width >= 8 do
    [decorate(["╰", rule(width - 1)], :light_black, styled?), "\n"]
  end

  def render(:close, _model, _workspace, _width, _styled?) do
    "\n"
  end

  defp top(model, workspace, width, styled?) do
    bounded_width = min(width, @maximum_width)
    available = bounded_width - 3
    context = model <> " · " <> workspace
    label = context <> @hint
    fits? = Data.length(label) <= available

    render_top(fits?, label, model, workspace, available, styled?)
  end

  defp render_top(true, label, model, workspace, available, styled?) do
    remainder = available - Data.length(label)

    [
      decorate("╭─ ", :light_black, styled?),
      decorate(model, [:yellow, :bright], styled?),
      decorate(" · ", :light_black, styled?),
      decorate(workspace, :green, styled?),
      decorate(@hint, :light_black, styled?),
      decorate(rule(remainder), :light_black, styled?)
    ]
  end

  defp render_top(false, label, _model, _workspace, available, styled?) do
    truncated = truncate(label, available)

    [
      decorate("╭─ ", :light_black, styled?),
      decorate(truncated, :light_black, styled?)
    ]
  end

  defp narrow_context(model, workspace, width, styled?) do
    model
    |> Kernel.<>(" · " <> workspace)
    |> truncate(width)
    |> decorate(:light_black, styled?)
  end

  defp truncate(content, width) do
    content
    |> Data.truncate(width)
    |> Data.to_chardata()
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
