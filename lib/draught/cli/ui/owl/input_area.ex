defmodule Draught.CLI.UI.Owl.InputArea do
  @moduledoc """
  Renders the bounded frame surrounding the interactive prompt editor.

  The top rail keeps active model and workspace context beside help discovery.
  The rails close at both corners while the input line remains open on the
  right so multiline content can wrap inside the editor-owned region. Styling
  is reset before the editor renders user text.
  """

  alias Draught.CLI.UI.Theme
  alias Elixir.Owl.Data

  @maximum_width 512
  @hint "  /help "

  @doc "Renders one input boundary with explicit terminal width and styling."
  @spec render(:open | :close, String.t(), String.t(), pos_integer(), boolean()) :: iodata()
  def render(:open, model, workspace, width, styled?) when width >= 8 do
    [
      "\n",
      top(model, workspace, width, styled?),
      "\n",
      decorate("│ ", :muted, styled?),
      decorate("›", :accent, styled?),
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
    [decorate(["╰", rule(width - 2), "╯"], :muted, styled?), "\n"]
  end

  def render(:close, _model, _workspace, _width, _styled?) do
    "\n"
  end

  defp top(model, workspace, width, styled?) do
    bounded_width = min(width, @maximum_width)
    available = bounded_width - 4
    context = model <> " · " <> workspace
    label = context <> @hint
    fits? = Data.length(label) <= available

    render_top(fits?, label, model, workspace, available, styled?)
  end

  defp render_top(true, label, model, workspace, available, styled?) do
    remainder = available - Data.length(label)

    [
      decorate("╭─ ", :muted, styled?),
      decorate(model, :model, styled?),
      decorate(" · ", :muted, styled?),
      decorate(workspace, :workspace, styled?),
      decorate(@hint, :muted, styled?),
      decorate(rule(remainder), :muted, styled?),
      decorate("╮", :muted, styled?)
    ]
  end

  defp render_top(false, label, _model, _workspace, available, styled?) do
    truncated = truncate(label, available)

    [
      decorate("╭─ ", :muted, styled?),
      decorate(truncated, :muted, styled?),
      decorate("╮", :muted, styled?)
    ]
  end

  defp narrow_context(model, workspace, width, styled?) do
    model
    |> Kernel.<>(" · " <> workspace)
    |> truncate(width)
    |> decorate(:muted, styled?)
  end

  defp truncate(content, width) do
    content
    |> Data.truncate(width)
    |> Data.to_chardata()
  end

  defp rule(width) do
    String.duplicate("─", min(width, @maximum_width - 2))
  end

  defp decorate(content, role, styled?) do
    Theme.chardata(content, role, styled?)
  end
end
