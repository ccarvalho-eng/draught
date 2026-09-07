defmodule Draught.CLI.UITest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Interactive.State
  alias Draught.CLI.UI

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

  defp render_banner(state, width, styled?) do
    state
    |> UI.banner(width, styled?)
    |> IO.iodata_to_binary()
  end
end
