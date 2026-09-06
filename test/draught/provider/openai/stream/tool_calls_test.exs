defmodule Draught.Provider.OpenAI.Stream.ToolCallsTest do
  use ExUnit.Case, async: true

  alias Draught.Error.Normalized
  alias Draught.Provider.OpenAI.Stream.ToolCalls

  test "assembles interleaved fragments and finalizes calls in index order" do
    assert {:ok, calls} = ToolCalls.new()

    assert {:ok, calls} =
             ToolCalls.append(calls, [
               fragment(1, "call-2", "inspect", ~s({"depth":)),
               fragment(0, "call-1", "read_file", ~s({"path":"))
             ])

    assert {:ok, calls} =
             ToolCalls.append(calls, [
               fragment(0, "call-1", "read_file", ~s(mix.exs"})),
               fragment(1, nil, nil, "2}")
             ])

    assert calls.argument_bytes == byte_size(~s({"depth":2})) + byte_size(~s({"path":"mix.exs"}))

    assert {:ok, [first, second]} = ToolCalls.finalize(calls)
    assert first.id == "call-1"
    assert first.name == "read_file"
    assert first.arguments == %{"path" => "mix.exs"}
    assert second.id == "call-2"
    assert second.name == "inspect"
    assert second.arguments == %{"depth" => 2}
  end

  test "accepts omitted repeated identity fields and empty fragment lists" do
    assert {:ok, calls} = ToolCalls.new()
    assert {:ok, ^calls} = ToolCalls.append(calls, nil)
    assert {:ok, ^calls} = ToolCalls.append(calls, [])

    assert {:ok, calls} = ToolCalls.append(calls, [fragment(0, "call-1", "inspect", "{")])

    assert {:ok, calls} =
             ToolCalls.append(calls, [
               %{"index" => 0, "function" => %{"arguments" => "}"}}
             ])

    assert {:ok, [call]} = ToolCalls.finalize(calls)
    assert call.arguments == %{}
  end

  test "rejects malformed fragments and conflicting identity" do
    malformed = [
      :invalid,
      [%{}],
      [%{"index" => -1}],
      [%{"index" => "0"}],
      [%{"index" => 0, "id" => ""}],
      [%{"index" => 0, "type" => "custom"}],
      [%{"index" => 0, "function" => "invalid"}],
      [%{"index" => 0, "function" => %{"name" => 1}}],
      [%{"index" => 0, "function" => %{"arguments" => %{}}}]
    ]

    Enum.each(malformed, fn fragments ->
      assert {:ok, calls} = ToolCalls.new()

      assert {:error, %Normalized{kind: :protocol, retryable: false}} =
               ToolCalls.append(calls, fragments)
    end)

    assert {:ok, calls} = ToolCalls.new()
    assert {:ok, calls} = ToolCalls.append(calls, [fragment(0, "call-1", "inspect", "{")])

    conflicts = [
      fragment(0, "call-2", nil, "}"),
      fragment(0, nil, "read_file", "}")
    ]

    Enum.each(conflicts, fn conflict ->
      assert {:error, %Normalized{code: "conflicting_tool_call"}} =
               ToolCalls.append(calls, [conflict])
    end)
  end

  test "rejects gaps, incomplete identity, malformed JSON, and duplicate call IDs" do
    invalid_sequences = [
      [fragment(1, "call-2", "inspect", "{}")],
      [%{"index" => 0, "type" => "function", "function" => %{"arguments" => "{}"}}],
      [fragment(0, "call-1", "inspect", "{")],
      [fragment(0, "call-1", "inspect", "[]")],
      [fragment(0, "call-1", "bad name", "{}")],
      [fragment(0, "duplicate", "one", "{}"), fragment(1, "duplicate", "two", "{}")]
    ]

    Enum.each(invalid_sequences, fn fragments ->
      assert {:ok, calls} = ToolCalls.new()
      assert {:ok, calls} = ToolCalls.append(calls, fragments)
      assert {:error, %Normalized{kind: :protocol}} = ToolCalls.finalize(calls)
    end)
  end

  test "bounds configuration, call indexes, and aggregate argument retention" do
    assert {:error, %Normalized{kind: :configuration}} = ToolCalls.new(max_calls: 0)
    assert {:error, %Normalized{kind: :configuration}} = ToolCalls.new(max_arguments_bytes: 0)
    assert {:error, %Normalized{kind: :configuration}} = ToolCalls.new(unknown: true)

    assert {:ok, calls} = ToolCalls.new(max_calls: 2, max_arguments_bytes: 8)

    assert {:error, %Normalized{code: "too_many_tool_calls"}} =
             ToolCalls.append(calls, [%{"index" => 2}])

    assert {:ok, calls} = ToolCalls.append(calls, [fragment(0, "call-1", "inspect", "1234")])

    assert {:error, %Normalized{code: "tool_arguments_too_large"}} =
             ToolCalls.append(calls, [%{"index" => 0, "function" => %{"arguments" => "56789"}}])
  end

  test "returns no calls when no fragments were received" do
    assert {:ok, calls} = ToolCalls.new()
    assert {:ok, []} = ToolCalls.finalize(calls)
  end

  test "does not retain rejected fragment content in errors" do
    assert {:ok, calls} = ToolCalls.new()
    fragment = %{"index" => 0, "function" => %{"arguments" => %{secret: "payload"}}}

    assert {:error, %Normalized{} = error} = ToolCalls.append(calls, [fragment])
    refute inspect(error) =~ "payload"
  end

  defp fragment(index, id, name, arguments) do
    %{
      "index" => index,
      "id" => id,
      "type" => "function",
      "function" => %{"name" => name, "arguments" => arguments}
    }
  end
end
