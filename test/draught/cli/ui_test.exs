defmodule Draught.CLI.UITest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Interactive.State
  alias Draught.CLI.Session.Catalog.Entry
  alias Draught.CLI.UI

  test "separates the input area without speaker names or cursor controls" do
    assert render_input(:open, 12) == "\n╭─ qwen3 · …\n│ › "
    assert render_input(:close, 12) == "╰───────────\n"

    tool =
      false
      |> UI.tool_label()
      |> IO.iodata_to_binary()

    assert tool == "Tool"
  end

  test "bounds input separators and uses a plain prompt for narrow terminals" do
    assert render_input(:open, 1) == "\n…\n>"
    assert render_input(:open, 6) == "\nqwen3…\n> "
    assert render_input(:close, 6) == "\n"

    opening = render_input(:open, 500)
    assert opening =~ "qwen3 · /workspace"
    assert opening =~ "/help"
    refute opening =~ "/model"

    assert opening
           |> String.split("\n", trim: true)
           |> Enum.all?(&(String.length(&1) <= 96))

    refute render_input(:open, 80) =~ <<27>>
  end

  test "keeps input hints and rounded edges within every supported width" do
    for width <- 1..120, phase <- [:open, :close] do
      output = render_input(phase, width)

      assert output
             |> String.split("\n", trim: true)
             |> Enum.all?(&(String.length(&1) <= width))
    end

    refute render_input(:open, 16) =~ "/help"
    assert render_input(:open, 40) =~ "/help"
    refute render_input(:open, 40) =~ "/model"
  end

  test "input styling is explicit and resets before terminal echo" do
    output =
      :open
      |> UI.input_area(state(), 40, true)
      |> IO.iodata_to_binary()

    assert output =~ "\e["
    assert String.ends_with?(output, "\e[0m ")
    assert Regex.replace(~r/\e\[[0-9;]*m/, output, "") == render_input(:open, 40)
  end

  test "bounds input context and sanitizes terminal-derived values" do
    state = %{state() | model: "safe\e[31mhidden", workspace: "/workspace\nforged"}

    output =
      :open
      |> UI.input_area(state, 20, false)
      |> IO.iodata_to_binary()

    assert output =~ "safehidden · /wo…"
    refute output =~ <<27>>
    refute output =~ "\nforged"
  end

  test "renders a bounded unstyled session card" do
    state = state()
    output = render_banner(state, 50, false)

    assert output =~ ">_ Draught (v"
    assert output =~ "model:     qwen3"
    assert output =~ "provider:  ollama"
    assert output =~ "directory: /workspace"
    assert output =~ "session:   session-01"
    assert output =~ "web:       disabled"
    refute output =~ <<27>>

    assert output
           |> String.split("\n", trim: true)
           |> Enum.all?(&(String.length(&1) <= 50))
  end

  test "accepts an explicit styling decision without changing the content" do
    styled = render_banner(state(), 50, true)

    assert styled =~ ">_ Draught"
    assert styled =~ "qwen3"
  end

  test "degrades to plain content in a narrow terminal" do
    output = render_banner(state(), 20, true)

    assert output =~ "Draught"
    assert output =~ "qwen3"
    refute output =~ "╭"
    refute output =~ <<27>>

    assert output
           |> String.split("\n", trim: true)
           |> Enum.all?(&(String.length(&1) <= 20))
  end

  test "sanitizes display values before rendering" do
    state = %{state() | model: "safe\e[31mhidden"}
    output = render_banner(state, 50, false)

    assert output =~ "safehidden"
    refute output =~ <<27>>
  end

  test "keeps filesystem-derived values on one structural line" do
    state = %{state() | workspace: "/workspace\n* fake\trow\u2028next"}

    status =
      state
      |> UI.status()
      |> IO.iodata_to_binary()

    refute status =~ "\n* fake"
    refute status =~ "\t"
    refute status =~ "\u2028"
    refute render_banner(state, 50, false) =~ "\n* fake"
    refute render_banner(state, 20, false) =~ "\n* fake"
  end

  test "renders shell help and the stable exit record" do
    help = IO.iodata_to_binary(UI.help())

    exit =
      "session-01"
      |> UI.session_closed()
      |> IO.iodata_to_binary()

    assert help =~ "Available commands"
    assert help =~ "/status"
    assert help =~ "/sessions"
    assert help =~ "Reserved for confined direct commands"
    assert exit == "Session ID: session-01\n"
  end

  test "numbers only the sessions visible in the requested view" do
    entries = [
      entry("active-one", :active),
      entry("archived", {:archived, ~U[2026-09-07 12:00:00Z]}),
      entry("active-two", :active)
    ]

    output =
      entries
      |> UI.sessions("active-one", :active)
      |> IO.iodata_to_binary()

    assert output =~ "1. * active-one"
    assert output =~ "2.   active-two"
    refute output =~ "archived"
  end

  defp state do
    {:ok, state} =
      State.new(
        session_id: "session-01",
        provider: "ollama",
        model: "qwen3",
        workspace: "/workspace",
        web: false
      )

    state
  end

  defp render_input(phase, width) do
    phase
    |> UI.input_area(state(), width)
    |> IO.iodata_to_binary()
  end

  defp render_banner(state, width, styled?) do
    state
    |> UI.banner(width, styled?)
    |> IO.iodata_to_binary()
  end

  defp entry(identifier, archive) do
    %Entry{
      archive: archive,
      availability: :available,
      id: identifier,
      label: identifier,
      model: "qwen3",
      profile: "ollama",
      provider: "ollama"
    }
  end
end
