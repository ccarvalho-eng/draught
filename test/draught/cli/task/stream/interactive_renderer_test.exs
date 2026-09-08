defmodule Draught.CLI.Task.Stream.InteractiveRendererTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Task.Stream.Event
  alias Draught.CLI.Task.Stream.Renderer.Interactive
  alias Draught.CLI.Task.Stream.Renderer.JSONL
  alias Draught.CLI.Task.Stream.Renderer.Text

  test "separates assistant speech without adding speaker labels" do
    opening = Event.new(:text_delta, 1, content: "First ", heading: true)
    continuation = Event.new(:text_delta, 2, content: "part", heading: false)
    ending = Event.new(:success, 3, content: ".", streamed: true, prefix_newline: true)

    assert render(opening) == "\nFirst "
    assert render(continuation) == "part"
    assert render(ending) == ".\n"
  end

  test "separates fallback responses and distinguishes bounded tool outcomes" do
    fallback = Event.new(:success, 1, content: "Done", streamed: false, heading: true)
    call = Event.new(:tool_call, 2, name: "read_file", prefix_newline: true)

    result =
      Event.new(:tool_result, 3,
        name: "read_file",
        status: :error,
        code: "not_found"
      )

    assert render(fallback) == "\nDone\n"
    assert render(call) == "\n  Tool: read_file (requested)\n"
    assert render(result) == "  Tool: read_file (error: not_found)\n"
  end

  test "presentation metadata does not alter plain text or JSONL records" do
    event = Event.new(:text_delta, 1, content: "answer", heading: true, iteration: 1)

    assert {:ok, "answer"} = Text.render(event)
    assert {:ok, encoded} = JSONL.render(event)

    decoded =
      encoded
      |> IO.iodata_to_binary()
      |> Jason.decode!()

    assert decoded["content"] == "answer"
    refute Map.has_key?(decoded, "heading")
    refute Map.has_key?(decoded, "presentation")
    refute render(event) =~ <<27>>
  end

  defp render(event) do
    {:ok, rendered} = Interactive.render(event, false)
    IO.iodata_to_binary(rendered)
  end
end
