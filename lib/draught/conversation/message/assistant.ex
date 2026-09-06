defmodule Draught.Conversation.Message.Assistant do
  @moduledoc """
  An assistant message containing ordered content parts and tool calls.
  """

  alias Draught.Conversation.Content
  alias Draught.Conversation.Content.Reasoning
  alias Draught.Conversation.Content.Text
  alias Draught.Tool.Call
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error

  @enforce_keys [:content, :tool_calls]
  defstruct [:content, :tool_calls]

  @type t :: %__MODULE__{
          content: [Text.t() | Reasoning.t()],
          tool_calls: [Call.t()]
        }

  @doc "Builds a validated assistant message."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes) do
    with {:ok, normalized} <-
           Attributes.normalize(attributes, [:content, :reasoning, :tool_calls]),
         {:ok, content} <- content(normalized),
         {:ok, tool_calls} <- tool_calls(normalized),
         :ok <- require_output(content, tool_calls),
         :ok <- unique_call_ids(tool_calls) do
      {:ok, %__MODULE__{content: content, tool_calls: tool_calls}}
    end
  end

  @doc "Builds the empty placeholder used when a provider filters its entire response."
  @spec filtered() :: t()
  def filtered do
    %__MODULE__{content: [], tool_calls: []}
  end

  defp content(attributes) do
    with {:ok, text_parts} <- content_parts(Map.get(attributes, :content), :text),
         {:ok, reasoning_parts} <- content_parts(Map.get(attributes, :reasoning), :reasoning) do
      {:ok, text_parts ++ reasoning_parts}
    end
  end

  defp content_parts(nil, _type) do
    {:ok, []}
  end

  defp content_parts(value, :text) when is_binary(value) do
    case Text.new(value, [:content]) do
      {:ok, part} -> {:ok, [part]}
      {:error, _error} = result -> result
    end
  end

  defp content_parts(value, :reasoning) when is_binary(value) do
    case Reasoning.new(value, [:reasoning]) do
      {:ok, part} -> {:ok, [part]}
      {:error, _error} = result -> result
    end
  end

  defp content_parts(parts, _type) when is_list(parts) do
    normalize_content_parts(parts)
  end

  defp content_parts(_value, type) do
    Error.single([type], :invalid_type, "must be a string or list of content parts")
  end

  defp normalize_content_parts(parts) do
    parts
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {part, index}, {:ok, normalized} ->
      case normalize_content_part(part, index) do
        {:ok, valid_part} -> {:cont, {:ok, [valid_part | normalized]}}
        {:error, _error} = result -> {:halt, result}
      end
    end)
    |> reverse_parts()
  end

  defp normalize_content_part(%Text{text: text}, index) do
    Text.new(text, [:content, index])
  end

  defp normalize_content_part(%Reasoning{text: text}, index) do
    Reasoning.new(text, [:content, index])
  end

  defp normalize_content_part(part, index) when is_map(part) or is_list(part) do
    case Content.new(part) do
      {:ok, content} -> {:ok, content}
      {:error, error} -> {:error, prefix_error(error, [:content, index])}
    end
  end

  defp normalize_content_part(_part, index) do
    Error.single([:content, index], :invalid_type, "must be a content part")
  end

  defp reverse_parts({:ok, parts}) do
    {:ok, Enum.reverse(parts)}
  end

  defp reverse_parts({:error, _error} = result) do
    result
  end

  defp tool_calls(attributes) do
    case Map.get(attributes, :tool_calls, []) do
      calls when is_list(calls) -> normalize_tool_calls(calls)
      _calls -> Error.single([:tool_calls], :invalid_type, "must be a list")
    end
  end

  defp normalize_tool_calls(calls) do
    calls
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {call, index}, {:ok, normalized} ->
      case normalize_tool_call(call, index) do
        {:ok, valid_call} -> {:cont, {:ok, [valid_call | normalized]}}
        {:error, _error} = result -> {:halt, result}
      end
    end)
    |> reverse_parts()
  end

  defp normalize_tool_call(%Call{} = call, index) do
    result =
      call
      |> Map.from_struct()
      |> Call.new()

    case result do
      {:ok, tool_call} -> {:ok, tool_call}
      {:error, error} -> {:error, prefix_error(error, [:tool_calls, index])}
    end
  end

  defp normalize_tool_call(call, index) when is_map(call) or is_list(call) do
    case Call.new(call) do
      {:ok, tool_call} -> {:ok, tool_call}
      {:error, error} -> {:error, prefix_error(error, [:tool_calls, index])}
    end
  end

  defp normalize_tool_call(_call, index) do
    Error.single([:tool_calls, index], :invalid_type, "must be a tool call")
  end

  defp require_output([], []) do
    Error.single([], :invalid_relationship, "must contain content or tool calls")
  end

  defp require_output(_content, _tool_calls) do
    :ok
  end

  defp unique_call_ids(tool_calls) do
    ids = Enum.map(tool_calls, & &1.id)

    ids
    |> unique?()
    |> unique_call_ids_result()
  end

  defp unique?(values) do
    unique_count =
      values
      |> MapSet.new()
      |> MapSet.size()

    unique_count == length(values)
  end

  defp unique_call_ids_result(true) do
    :ok
  end

  defp unique_call_ids_result(false) do
    Error.single([:tool_calls], :invalid_relationship, "must have unique call IDs")
  end

  defp prefix_error(%Error{violations: violations}, prefix) do
    prefixed =
      Enum.map(violations, fn violation ->
        %{violation | path: prefix ++ violation.path}
      end)

    Error.new(prefixed)
  end
end
