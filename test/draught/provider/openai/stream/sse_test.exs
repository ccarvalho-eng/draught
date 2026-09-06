defmodule Draught.Provider.OpenAI.Stream.SSETest do
  use ExUnit.Case, async: true

  alias Draught.Error.Normalized
  alias Draught.Provider.OpenAI.Stream.SSE

  test "parses ordered data frames, comments, CRLF, and multiline data" do
    assert {:ok, parser} = SSE.new()

    chunk =
      ": keep-alive\r\n\r\n" <>
        "event: message\r\ndata: {\"first\":1}\r\n\r\n" <>
        "data: first\r\ndata: second\r\n\r\n" <>
        "data: [DONE]\r\n\r\n"

    assert {:done, terminal, data} = SSE.push(parser, chunk)
    assert data == [~s({"first":1}), "first\nsecond"]
    assert terminal.status == :done
    assert :ok = SSE.finish(terminal)
  end

  test "produces the same frames at every byte boundary" do
    fixture =
      ": ping\r\n\r\n" <>
        ~s|data: {"choices":[{"index":0}]}\r\n\r\n| <>
        ~s|data: {"choices":[]}\r\n\r\n| <>
        "data: [DONE]\r\n\r\n"

    expected = [~s({"choices":[{"index":0}]}), ~s({"choices":[]})]

    assert {:ok, parser} = SSE.new()
    assert {:done, _parser, ^expected} = consume(parser, [fixture])

    chunks = for <<byte <- fixture>>, do: <<byte>>
    assert {:done, _parser, ^expected} = consume(parser, chunks)
  end

  test "retains only an incomplete frame between pushes" do
    assert {:ok, parser} = SSE.new(max_event_bytes: 64)

    assert {:ok, parser, []} = SSE.push(parser, "data: {\"value\":")
    assert parser.buffer == "data: {\"value\":"

    assert {:ok, parser, [~s({"value":true})]} = SSE.push(parser, "true}\n\n")
    assert parser.buffer == ""

    assert {:done, parser, []} = SSE.push(parser, "data: [DONE]\n\n")
    assert :ok = SSE.finish(parser)
  end

  test "requires the terminal sentinel before transport closure" do
    assert {:ok, parser} = SSE.new()
    assert {:ok, parser, ["{}"]} = SSE.push(parser, "data: {}\n\n")

    assert {:error,
            %Normalized{
              kind: :protocol,
              code: "incomplete_stream",
              retryable: false
            }} = SSE.finish(parser)
  end

  test "rejects input and data after terminal state" do
    assert {:ok, parser} = SSE.new()

    assert {:error, %Normalized{code: "data_after_done"}} =
             SSE.push(parser, "data: [DONE]\n\ndata: {}\n\n")

    assert {:done, terminal, []} = SSE.push(parser, "data: [DONE]\n\n")

    assert {:error, %Normalized{code: "data_after_done"}} =
             SSE.push(terminal, "data: {}\n\n")
  end

  test "enforces a bounded incomplete buffer and complete event" do
    assert {:ok, parser} = SSE.new(max_event_bytes: 16)

    assert {:error, %Normalized{code: "event_too_large"}} =
             SSE.push(parser, "data: 12345678901")

    assert {:error, %Normalized{code: "event_too_large"}} =
             SSE.push(parser, "data: 12345678901\n\n")
  end

  test "validates parser configuration and input types" do
    assert {:error, %Normalized{kind: :configuration}} = SSE.new(max_event_bytes: 0)
    assert {:error, %Normalized{kind: :configuration}} = SSE.new(max_event_bytes: 8_388_609)
    assert {:error, %Normalized{kind: :configuration}} = SSE.new(unknown: true)

    assert {:ok, parser} = SSE.new()
    assert {:error, %Normalized{kind: :protocol}} = SSE.push(parser, :not_binary)
  end

  defp consume(parser, chunks) do
    Enum.reduce_while(chunks, {:ok, parser, []}, fn chunk, {_status, state, all_data} ->
      case SSE.push(state, chunk) do
        {:ok, next, data} -> {:cont, {:ok, next, all_data ++ data}}
        {:done, next, data} -> {:halt, {:done, next, all_data ++ data}}
        {:error, %Normalized{}} = error -> {:halt, error}
      end
    end)
  end
end
