defmodule Draught.CLI.Task.Stream.Renderer.JSONL do
  @moduledoc """
  Encodes safe projected CLI events as independent versioned JSON Lines records.
  """

  alias Draught.CLI.Task.Stream.Event

  @schema "draught.cli/v1"

  @doc "Encodes one projected event as one complete JSONL record."
  @spec render(Event.t()) :: {:ok, iodata()} | {:error, :encoding}
  def render(%Event{type: :text_delta} = event) do
    encode(event, %{
      "type" => "event",
      "event" => "text_delta",
      "iteration" => event.iteration,
      "content" => event.content
    })
  end

  def render(%Event{type: :tool_call} = event) do
    encode(event, %{
      "type" => "event",
      "event" => "tool_call",
      "iteration" => event.iteration,
      "name" => event.name
    })
  end

  def render(%Event{type: :tool_result} = event) do
    encode(event, %{
      "type" => "event",
      "event" => "tool_result",
      "iteration" => event.iteration,
      "name" => event.name,
      "status" => Atom.to_string(event.status),
      "code" => event.code
    })
  end

  def render(%Event{type: :success} = event) do
    encode(event, %{
      "type" => "terminal",
      "status" => "ok",
      "content" => event.content,
      "content_streamed" => event.streamed,
      "finish_reason" => Atom.to_string(event.finish_reason),
      "usage" => event.usage
    })
  end

  def render(%Event{type: :failure} = event) do
    encode(event, %{
      "type" => "terminal",
      "status" => "error",
      "category" => Atom.to_string(event.category),
      "kind" => Atom.to_string(event.kind),
      "code" => event.code,
      "message" => event.message,
      "retryable" => event.retryable
    })
  end

  defp encode(event, fields) do
    value = Map.merge(fields, %{"schema" => @schema, "sequence" => event.sequence})

    case Jason.encode(value) do
      {:ok, encoded} -> {:ok, [encoded, "\n"]}
      {:error, _error} -> {:error, :encoding}
    end
  end
end
