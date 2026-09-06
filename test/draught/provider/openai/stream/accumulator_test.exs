defmodule Draught.Provider.OpenAI.Stream.AccumulatorTest do
  use ExUnit.Case, async: true

  alias Draught.Conversation.Content.Reasoning
  alias Draught.Conversation.Content.Text
  alias Draught.Error.Normalized
  alias Draught.Event.Provider.Delta
  alias Draught.Event.Provider.ToolCall
  alias Draught.Provider.OpenAI.Stream.Accumulator

  test "emits reasoning and text deltas and builds the final response" do
    assert {:ok, stream} = Accumulator.new()
    refute Accumulator.output?(stream)

    assert {:ok, stream, [%Delta{kind: :reasoning, content: "Consider"}]} =
             Accumulator.push(
               stream,
               chunk(%{"role" => "assistant", "reasoning_content" => "Consider"})
             )

    assert Accumulator.output?(stream)

    assert {:ok, stream, [%Delta{kind: :text, content: "Answer"}]} =
             Accumulator.push(stream, chunk(%{"content" => "Answer"}, "stop", usage()))

    assert {:ok, response} = Accumulator.finish(stream)
    assert response.finish_reason == :stop
    assert response.message.content == [%Text{text: "Answer"}, %Reasoning{text: "Consider"}]
    assert response.message.tool_calls == []
    assert response.usage.input_tokens == 8
    assert response.usage.output_tokens == 3
  end

  test "assembles interleaved tool calls and emits them only at their finish boundary" do
    assert {:ok, stream} = Accumulator.new()

    fragments = [
      tool_fragment(1, "call-2", "inspect", ~s({"depth":)),
      tool_fragment(0, "call-1", "read_file", ~s({"path":"))
    ]

    assert {:ok, stream, []} =
             Accumulator.push(stream, chunk(%{"tool_calls" => fragments}))

    refute Accumulator.output?(stream)

    remaining_fragments = [
      tool_fragment(0, nil, nil, ~s(mix.exs"})),
      tool_fragment(1, nil, nil, "2}")
    ]

    assert {:ok, stream, [%ToolCall{call: first}, %ToolCall{call: second}]} =
             Accumulator.push(
               stream,
               chunk(%{"tool_calls" => remaining_fragments}, "tool_calls")
             )

    assert first.id == "call-1"
    assert first.arguments == %{"path" => "mix.exs"}
    assert second.id == "call-2"
    assert second.arguments == %{"depth" => 2}
    assert Accumulator.output?(stream)

    assert {:ok, response} = Accumulator.finish(stream)
    assert response.finish_reason == :tool_calls
    assert response.message.tool_calls == [first, second]
  end

  test "accepts one usage-only chunk after the finishing choice" do
    assert {:ok, stream} = Accumulator.new()

    assert {:ok, stream, [_event]} =
             Accumulator.push(stream, chunk(%{"content" => "Done"}, "stop"))

    assert {:ok, stream, []} = Accumulator.push(stream, usage_chunk(usage()))
    assert {:ok, response} = Accumulator.finish(stream)
    assert response.usage.total_tokens == 11

    assert {:error, %Normalized{code: "duplicate_usage"}} =
             Accumulator.push(stream, usage_chunk(usage()))
  end

  test "maps compatible reasoning and finish fields" do
    assert {:ok, stream} = Accumulator.new()

    assert {:ok, stream, [%Delta{kind: :reasoning, content: "Plan"}]} =
             Accumulator.push(stream, chunk(%{"reasoning" => "Plan"}))

    assert {:ok, stream, [%Delta{kind: :text, content: "Result"}]} =
             Accumulator.push(stream, chunk(%{"content" => "Result"}, "provider_stop"))

    assert {:ok, response} = Accumulator.finish(stream)
    assert response.finish_reason == :other
  end

  test "supports an empty content-filtered response" do
    assert {:ok, stream} = Accumulator.new()

    assert {:ok, stream, []} =
             Accumulator.push(stream, chunk(%{"content" => nil}, "content_filter"))

    assert {:ok, response} = Accumulator.finish(stream)
    assert response.finish_reason == :content_filter
    assert response.message.content == []
    assert response.message.tool_calls == []
  end

  test "rejects malformed JSON, envelopes, choices, and deltas" do
    invalid = [
      "not-json",
      Jason.encode!([]),
      Jason.encode!(%{}),
      Jason.encode!(%{"choices" => []}),
      Jason.encode!(%{"choices" => [%{"index" => 1, "delta" => %{}}]}),
      Jason.encode!(%{"choices" => [%{"index" => 0, "delta" => "invalid"}]}),
      chunk(%{"role" => "user"}),
      chunk(%{"content" => 1}),
      chunk(%{"reasoning" => 1}),
      chunk(%{"reasoning" => "one", "reasoning_content" => "two"}),
      chunk(%{"tool_calls" => "invalid"})
    ]

    Enum.each(invalid, fn data ->
      assert {:ok, stream} = Accumulator.new()

      assert {:error, %Normalized{kind: :protocol, retryable: false}} =
               Accumulator.push(stream, data)
    end)
  end

  test "rejects invalid stream ordering and incomplete final state" do
    assert {:ok, initial} = Accumulator.new()
    assert {:error, %Normalized{code: "incomplete_stream"}} = Accumulator.finish(initial)

    assert {:error, %Normalized{code: "usage_before_finish"}} =
             Accumulator.push(initial, usage_chunk(usage()))

    assert {:error, %Normalized{code: "invalid_stream_finish"}} =
             Accumulator.push(initial, chunk(%{}, "stop"))

    assert {:error, %Normalized{code: "invalid_stream_finish"}} =
             Accumulator.push(initial, chunk(%{}, "tool_calls"))

    assert {:ok, partial, []} =
             Accumulator.push(
               initial,
               chunk(%{"tool_calls" => [tool_fragment(0, "call-1", "inspect", "{")]})
             )

    assert {:error, %Normalized{code: "invalid_stream_finish"}} =
             Accumulator.push(partial, chunk(%{"content" => "Done"}, "stop"))

    assert {:ok, finished, [_event]} =
             Accumulator.push(initial, chunk(%{"content" => "Done"}, "stop"))

    assert {:error, %Normalized{code: "data_after_finish"}} =
             Accumulator.push(finished, chunk(%{"content" => "extra"}))
  end

  test "ignores empty deltas and does not cross the output boundary" do
    assert {:ok, stream} = Accumulator.new()

    assert {:ok, stream, []} =
             Accumulator.push(stream, chunk(%{"role" => "assistant", "content" => ""}))

    refute Accumulator.output?(stream)
  end

  test "bounds aggregate text and reasoning retention" do
    assert {:error, %Normalized{kind: :configuration}} = Accumulator.new(max_output_bytes: 0)
    assert {:error, %Normalized{kind: :configuration}} = Accumulator.new(unknown: true)
    assert {:ok, stream} = Accumulator.new(max_output_bytes: 4)
    assert {:ok, stream, [_event]} = Accumulator.push(stream, chunk(%{"content" => "1234"}))

    assert {:error, %Normalized{code: "stream_output_too_large"}} =
             Accumulator.push(stream, chunk(%{"reasoning" => "5"}))

    assert {:ok, stream} = Accumulator.new(max_output_fragments: 1)
    assert {:ok, stream, [_event]} = Accumulator.push(stream, chunk(%{"content" => "1"}))

    assert {:error, %Normalized{code: "too_many_stream_fragments"}} =
             Accumulator.push(stream, chunk(%{"content" => "2"}))
  end

  test "does not retain rejected payload content in errors" do
    assert {:ok, stream} = Accumulator.new()
    rejected = chunk(%{"content" => %{"secret-payload" => true}})

    assert {:error, %Normalized{} = error} = Accumulator.push(stream, rejected)
    refute inspect(error) =~ "secret-payload"
  end

  defp chunk(delta, finish_reason \\ nil, usage \\ nil) do
    payload = %{
      "choices" => [
        %{
          "index" => 0,
          "delta" => delta,
          "finish_reason" => finish_reason
        }
      ],
      "usage" => usage
    }

    Jason.encode!(payload)
  end

  defp usage_chunk(value) do
    Jason.encode!(%{"choices" => [], "usage" => value})
  end

  defp usage do
    %{
      "prompt_tokens" => 8,
      "completion_tokens" => 3,
      "total_tokens" => 11,
      "completion_tokens_details" => %{"reasoning_tokens" => 1}
    }
  end

  defp tool_fragment(index, id, name, arguments) do
    %{
      "index" => index,
      "id" => id,
      "type" => identity_type(id),
      "function" => %{"name" => name, "arguments" => arguments}
    }
  end

  defp identity_type(nil) do
    nil
  end

  defp identity_type(_id) do
    "function"
  end
end
