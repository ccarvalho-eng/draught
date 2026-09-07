defmodule Draught.CLI.Task.Output do
  @moduledoc false

  alias Draught.CLI.Output.Sanitizer
  alias Draught.Conversation.Content.Text
  alias Draught.Error.Normalized
  alias Draught.Provider.Response

  @schema "draught.cli/v1"
  @doc "Renders a successful task response in the selected output format."
  @spec success(Response.t(), :text | :jsonl) :: {:ok, iodata()} | {:error, :encoding}
  def success(%Response{} = response, :text) do
    {:ok, [content(response), "\n"]}
  end

  def success(%Response{} = response, :jsonl) do
    encode(%{
      "schema" => @schema,
      "type" => "task",
      "status" => "ok",
      "content" => content(response),
      "finish_reason" => Atom.to_string(response.finish_reason),
      "usage" => usage(response)
    })
  end

  @doc "Renders one safe task error record."
  @spec error(Normalized.t(), atom(), :text | :jsonl) ::
          {:ok, iodata()} | {:error, :encoding}
  def error(%Normalized{} = error, _category, :text) do
    {:ok,
     [
       "Task failed (",
       Sanitizer.text(error.code),
       "): ",
       Sanitizer.text(error.message),
       hint(error.hint),
       "\n"
     ]}
  end

  def error(%Normalized{} = error, category, :jsonl) do
    encode(%{
      "schema" => @schema,
      "type" => "error",
      "category" => Atom.to_string(category),
      "kind" => Atom.to_string(error.kind),
      "code" => Sanitizer.text(error.code),
      "message" => Sanitizer.text(error.message),
      "hint" => optional_text(error.hint),
      "retryable" => error.retryable
    })
  end

  defp content(response) do
    response.message.content
    |> Enum.flat_map(fn
      %Text{text: text} -> [text]
      _content -> []
    end)
    |> IO.iodata_to_binary()
    |> Sanitizer.text()
  end

  defp usage(%Response{usage: nil}) do
    nil
  end

  defp usage(%Response{usage: usage}) do
    usage
    |> Map.from_struct()
    |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end)
  end

  defp hint(nil) do
    []
  end

  defp hint(value) do
    [" ", Sanitizer.text(value)]
  end

  defp optional_text(nil) do
    nil
  end

  defp optional_text(value) do
    Sanitizer.text(value)
  end

  defp encode(value) do
    case Jason.encode(value) do
      {:ok, encoded} -> {:ok, [encoded, "\n"]}
      {:error, _error} -> {:error, :encoding}
    end
  end
end
