defmodule Draught.CLI.UI.Owl do
  @moduledoc """
  Renders bounded interactive presentation data through Owl.

  This adapter performs no input, session, provider, or approval work. Callers
  decide terminal capability and explicitly enable styling.
  """

  alias Draught.CLI.Interactive.State
  alias Draught.CLI.UI.Owl.InputArea
  alias Draught.CLI.UI.SafeLine
  alias Draught.CLI.UI.Workspace
  alias Elixir.Owl.Box
  alias Elixir.Owl.Data

  @maximum_width 64
  @minimum_box_width 32

  @doc "Renders a session card with an explicit width and styling decision."
  @spec banner(State.t(), pos_integer(), boolean()) :: iodata()
  def banner(%State{} = state, width, styled?) do
    safe_width = min(width, @maximum_width)
    render_banner(state, safe_width, styled?)
  end

  @doc "Renders rounded input boundaries with active model and workspace context."
  @spec input_area(:open | :close, State.t(), pos_integer(), boolean()) :: iodata()
  def input_area(phase, %State{} = state, width, styled?) do
    InputArea.render(
      phase,
      model(state.model),
      Workspace.display(state.workspace),
      width,
      styled?
    )
  end

  @doc "Renders a fixed tool label without styling untrusted conversation text."
  @spec tool_label(boolean()) :: iodata()
  def tool_label(styled?) do
    "Tool"
    |> Data.tag(style(:bright, styled?))
    |> styling(styled?)
    |> Data.to_chardata()
  end

  defp render_banner(state, width, styled?) when width >= @minimum_box_width do
    boxed(state, width, styled?)
  end

  defp render_banner(state, width, _styled?) do
    narrow(state, width)
  end

  defp boxed(state, width, styled?) do
    state
    |> content(styled?)
    |> Box.new(
      border_style: :solid_rounded,
      border_tag: style(:light_black, styled?),
      max_width: width,
      min_width: width,
      padding_x: 1,
      truncate_lines: true
    )
    |> styling(styled?)
    |> Data.to_chardata()
    |> then(&[&1, "\n"])
  end

  defp narrow(state, width) do
    [
      [">_ Draught ", version()],
      ["model: ", model(state.model)],
      ["provider: ", safe(state.provider)],
      ["session: ", safe(state.session_label)]
    ]
    |> Enum.map(&bounded_line(&1, width))
    |> Enum.intersperse("\n")
    |> then(&[&1, "\n"])
  end

  defp content(state, styled?) do
    [
      title(styled?),
      "\n\n",
      label("model:", styled?),
      "     ",
      model(state.model),
      "   /model to change\n",
      label("provider:", styled?),
      "  ",
      safe(state.provider),
      "\n",
      label("directory:", styled?),
      " ",
      Workspace.display(state.workspace),
      "\n",
      label("session:", styled?),
      "   ",
      safe(state.session_label),
      "\n",
      label("web:", styled?),
      "       ",
      web(state.web)
    ]
  end

  defp title(styled?) do
    Data.tag([">_ Draught ", version()], style([:cyan, :bright], styled?))
  end

  defp label(value, styled?) do
    Data.tag(value, style(:light_black, styled?))
  end

  defp styling(data, true) do
    data
  end

  defp styling(data, false) do
    Data.untag(data)
  end

  defp style(sequence, true) do
    sequence
  end

  defp style(_sequence, false) do
    []
  end

  defp safe(value) do
    SafeLine.text(value, 2_048)
  end

  defp model(nil) do
    "selection required"
  end

  defp model(value) do
    safe(value)
  end

  defp bounded_line(line, width) do
    line
    |> Data.truncate(width)
    |> Data.untag()
    |> Data.to_chardata()
  end

  defp version do
    ["(v", to_string(Application.spec(:draught, :vsn)), ")"]
  end

  defp web(true) do
    "enabled"
  end

  defp web(false) do
    "disabled"
  end
end
