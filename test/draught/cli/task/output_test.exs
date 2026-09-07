defmodule Draught.CLI.Task.OutputTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Task.Output
  alias Draught.Conversation
  alias Draught.Error.Normalized
  alias Draught.Provider.Response

  test "renders visible assistant text without reasoning or terminal controls" do
    assert {:ok, assistant} =
             Conversation.assistant(
               content: [
                 %{type: :text, text: "first\e[31m\n"},
                 %{type: :reasoning, text: "private"},
                 %{type: :text, text: "second\u202E"}
               ]
             )

    assert {:ok, response} = Response.new(message: assistant, finish_reason: :stop)
    assert {:ok, rendered} = Output.success(response, :text)
    assert IO.iodata_to_binary(rendered) == "first\nsecond\n"
  end

  test "sanitizes normalized error fields before text and JSONL rendering" do
    assert {:ok, error} =
             Normalized.new(
               :transport,
               "unsafe\e[31m",
               "offline\u202E\rrewritten",
               hint: "retry\e]0;title\a",
               retryable: true
             )

    assert {:ok, text} = Output.error(error, :execution, :text)
    rendered = IO.iodata_to_binary(text)
    refute rendered =~ <<27>>
    refute rendered =~ "\u202E"
    refute rendered =~ "\r"

    assert {:ok, jsonl} = Output.error(error, :provider, :jsonl)

    decoded =
      jsonl
      |> IO.iodata_to_binary()
      |> Jason.decode!()

    assert decoded["category"] == "provider"
    refute decoded["message"] =~ "\u202E"
    refute decoded["hint"] =~ <<27>>
  end

  test "emits one stable JSONL task record" do
    assert {:ok, assistant} = Conversation.assistant(content: "done")
    assert {:ok, response} = Response.new(message: assistant, finish_reason: :stop)

    assert {:ok, rendered} = Output.success(response, :jsonl)

    lines =
      rendered
      |> IO.iodata_to_binary()
      |> String.split("\n", trim: true)

    assert [line] = lines

    assert %{"schema" => "draught.cli/v1", "status" => "ok", "type" => "task"} =
             Jason.decode!(line)
  end
end
