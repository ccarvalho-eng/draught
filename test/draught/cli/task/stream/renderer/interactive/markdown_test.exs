defmodule Draught.CLI.Task.Stream.Renderer.Interactive.MarkdownTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Task.Stream.Renderer.Interactive.Markdown

  test "streams prose immediately and recognizes a split Elixir fence" do
    state = Markdown.new()

    assert {"Answer:\n", state} = render(state, "Answer:\n")
    assert {"", state} = render(state, "`")
    assert {opening, state} = render(state, "``elixir\n")
    assert strip_style(opening) == "```elixir\n"

    assert {"", state} = render(state, "defmodule Demo")
    assert {code, state} = render(state, " do\n")
    assert strip_style(code) == "defmodule Demo do\n"
    assert code =~ IO.ANSI.magenta()
    assert code =~ IO.ANSI.cyan()

    assert {ending, _state} = render(state, "end\n```\nDone")
    assert strip_style(ending) == "end\n```\nDone"
  end

  test "keeps unsupported fenced languages plain" do
    state = Markdown.new()

    assert {opening, state} = render(state, "```rust\n")
    assert strip_style(opening) == "```rust\n"

    assert {code, state} = render(state, "fn main() {}\n")
    assert code == "fn main() {}\n"

    assert {closing, _state} = render(state, "```\n")
    assert strip_style(closing) == "```\n"
  end

  test "flushes incomplete fences and code without losing content" do
    state = Markdown.new()

    assert {opening, state} = render(state, "```elixir\n")
    assert {"", state} = render(state, "def answer, do: 42")
    assert {pending, reset} = Markdown.flush(state)

    assert strip_style([opening, pending]) == "```elixir\ndef answer, do: 42"
    assert {"next", _state} = render(reset, "next")
  end

  test "bounds retained opening markers and code lines" do
    state = Markdown.new()
    long_information = "```" <> String.duplicate("x", 130) <> "\nafter\n"

    assert {opening, state} = render(state, long_information)
    assert opening == long_information

    assert {fence, state} = render(state, "```elixir\n")
    long_code = String.duplicate("x", 4_097)
    assert {^long_code, state} = render(state, long_code)
    assert {"tail\n", state} = render(state, "tail\n")

    assert {highlighted, _state} = render(state, "def next, do: :ok\n```\n")
    assert strip_style([fence, highlighted]) == "```elixir\ndef next, do: :ok\n```\n"
    assert highlighted =~ IO.ANSI.magenta()
  end

  test "degrades newline-heavy deltas without retaining parser state" do
    state = Markdown.new()
    content = String.duplicate("line\n", 513)

    assert {^content, reset} = render(state, content)
    assert reset == Markdown.new()
  end

  test "preserves content across single-character stream boundaries" do
    content = "Intro\n```elixir\ndefmodule Demo do\nend\n```\nDone"

    {parts, state} =
      content
      |> String.graphemes()
      |> Enum.reduce({[], Markdown.new()}, fn grapheme, {parts, state} ->
        {output, updated} = Markdown.consume(state, grapheme)
        {[output | parts], updated}
      end)

    {pending, _reset} = Markdown.flush(state)
    rendered_parts = Enum.reverse(parts)
    output = [rendered_parts, pending]

    assert strip_style(output) == content
  end

  defp render(state, content) do
    {output, updated} = Markdown.consume(state, content)
    {IO.iodata_to_binary(output), updated}
  end

  defp strip_style(value) do
    value
    |> IO.iodata_to_binary()
    |> then(&Regex.replace(~r/\e\[[0-9;]*m/, &1, ""))
  end
end
