defmodule Draught.CLI.Task.Stream.ProjectorTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Task.Stream.Projector
  alias Draught.CLI.Task.Stream.Projector.State
  alias Draught.Conversation
  alias Draught.Error.Normalized
  alias Draught.Event.Provider.Delta
  alias Draught.Event.Provider.ToolCall
  alias Draught.Provider.Response
  alias Draught.Tool.Call
  alias Draught.Tool.Result

  test "marks assistant segments once across deltas and after tool activity" do
    state = State.new(:text, 1_024, presentation: :interactive)

    assert {:emit, first, opening} =
             Projector.project(state, {:provider_event, 1, delta(:text, "Let me ")})

    assert opening.heading

    assert {:emit, second, continuation} =
             Projector.project(first, {:provider_event, 1, delta(:text, "check.")})

    refute continuation.heading

    assert {:emit, after_tool, _tool} =
             Projector.project(second, {:provider_event, 1, tool_call(call("file"))})

    assert {:emit, _resumed, resumed} =
             Projector.project(after_tool, {:provider_event, 2, delta(:text, "Found it.")})

    assert resumed.heading
  end

  test "projects only safe ordered provider and tool fields" do
    state = State.new(:jsonl, 1_024)
    reasoning = delta(:reasoning, "private reasoning")

    assert {:skip, ^state} = Projector.project(state, {:provider_event, 1, reasoning})

    call = call("lib/example.ex", %{"content" => "secret argument"})

    assert {:emit, after_call, projected_call} =
             Projector.project(state, {:provider_event, 1, tool_call(call)})

    assert projected_call.sequence == 1
    assert projected_call.type == :tool_call
    assert projected_call.name == "read_file"
    assert projected_call.target == "lib/example.ex"
    projected_call_fields = Map.from_struct(projected_call)
    refute Map.has_key?(projected_call_fields, :arguments)
    projected_call_inspection = inspect(projected_call)
    refute projected_call_inspection =~ "secret argument"

    result = result("secret tool output")

    assert {:emit, after_result, projected_result} =
             Projector.project(after_call, {:tool_result, 1, result})

    assert projected_result.sequence == 2
    assert projected_result.type == :tool_result
    assert projected_result.status == :success
    projected_result_inspection = inspect(projected_result)
    refute projected_result_inspection =~ "secret tool output"
    assert after_result.sequence == 3
  end

  test "projects only safe relative targets for filesystem tool calls" do
    state = State.new(:text, 1_024, presentation: :interactive)

    assert {:emit, after_relative, relative} =
             Projector.project(
               state,
               {:provider_event, 1, tool_call(call("novels/frostgard\n/AGENTS.md"))}
             )

    assert relative.target == "novels/frostgard /AGENTS.md"

    assert {:emit, after_absolute, absolute} =
             Projector.project(
               after_relative,
               {:provider_event, 1, tool_call(call("/Users/example/private.txt"))}
             )

    assert absolute.target == nil

    assert {:emit, after_bounded, bounded} =
             Projector.project(
               after_absolute,
               {:provider_event, 1, tool_call(call(String.duplicate("a", 200)))}
             )

    assert byte_size(bounded.target) == 160

    assert {:emit, _after_unsupported, unsupported} =
             Projector.project(
               after_bounded,
               {:provider_event, 1, tool_call(call("run_command", "private.txt", %{}))}
             )

    assert unsupported.target == nil
  end

  test "suppresses terminal content already delivered as text deltas" do
    state = State.new(:jsonl, 1_024)
    text = delta(:text, "done")
    response = response("done")

    assert {:emit, streamed, event} =
             Projector.project(state, {:provider_event, 1, text})

    assert event.sequence == 1

    assert {:skip, retained} =
             Projector.project(streamed, {:provider_result, 1, {:ok, response}})

    assert {:emit, terminal, projected} = Projector.finish(retained, {:ok, response})
    assert projected.sequence == 2
    assert projected.type == :success
    assert projected.streamed
    assert is_nil(projected.content)
    assert terminal.status == :terminal
    assert {:error, :invalid_event} = Projector.finish(terminal, {:ok, response})
  end

  test "uses completed content when a provider emitted no visible text" do
    state = State.new(:text, 1_024)
    response = response("fallback")

    assert {:skip, retained} =
             Projector.project(state, {:provider_result, 1, {:ok, response}})

    assert {:emit, _terminal, projected} = Projector.finish(retained, {:ok, response})
    refute projected.streamed
    assert projected.content == "fallback"
    assert projected.heading
  end

  test "emits only a missing final suffix after visible text deltas" do
    state = State.new(:text, 1_024)
    response = response("partial")

    assert {:emit, streamed, _event} =
             Projector.project(state, {:provider_event, 1, delta(:text, "par")})

    assert {:skip, retained} =
             Projector.project(streamed, {:provider_result, 1, {:ok, response}})

    assert {:emit, _terminal, projected} = Projector.finish(retained, {:ok, response})
    assert projected.streamed
    assert projected.content == "tial"
    assert projected.prefix_newline
    refute projected.heading
  end

  test "rejects a terminal response that disagrees with visible streamed text" do
    state = State.new(:text, 1_024)
    response = response("complete")

    assert {:emit, streamed, _event} =
             Projector.project(state, {:provider_event, 1, delta(:text, "partial")})

    assert {:skip, retained} =
             Projector.project(streamed, {:provider_result, 1, {:ok, response}})

    assert {:error, :inconsistent_stream} = Projector.finish(retained, {:ok, response})
  end

  test "sanitizes provider text and normalized failures" do
    state = State.new(:text, 1_024)
    text = delta(:text, "safe\e]0;unsafe\a")

    assert {:emit, updated, projected} =
             Projector.project(state, {:provider_event, 1, text})

    assert projected.content == "safe"

    {:ok, error} =
      Normalized.new(:transport, "closed\e]0;x\a", "failed\e]0;y\a", retryable: true)

    assert {:emit, _terminal, failure} =
             Projector.finish(updated, {:error, :execution, error})

    refute failure.code =~ <<27>>
    refute failure.message =~ <<27>>
  end

  defp delta(kind, content) do
    {:ok, event} = Delta.new(kind: kind, content: content)
    event
  end

  defp call(path, arguments \\ %{}) do
    call("read_file", path, arguments)
  end

  defp call(name, path, arguments) do
    arguments = Map.put(arguments, "path", path)
    {:ok, value} = Call.new(id: "call-1", name: name, arguments: arguments)
    value
  end

  defp tool_call(call) do
    {:ok, event} = ToolCall.new(call: call)
    event
  end

  defp result(content) do
    {:ok, value} =
      Result.new(call_id: "call-1", name: "read_file", content: content, status: :success)

    value
  end

  defp response(content) do
    {:ok, assistant} = Conversation.assistant(content: content)
    {:ok, value} = Response.new(message: assistant, finish_reason: :stop)
    value
  end
end
