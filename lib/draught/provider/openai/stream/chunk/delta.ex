defmodule Draught.Provider.OpenAI.Stream.Chunk.Delta do
  @moduledoc "Validates the provider fields contained in one streamed choice delta."

  alias Draught.Provider.OpenAI.Protocol
  alias Draught.Validation.Value

  @enforce_keys [:tool_calls]
  defstruct [:content, :reasoning, :tool_calls]

  @type t :: %__MODULE__{
          content: String.t() | nil,
          reasoning: String.t() | nil,
          tool_calls: nil | [term()]
        }

  @doc "Validates assistant role, content, reasoning, and tool-call fragments."
  @spec decode(term()) :: {:ok, t()} | {:error, Draught.Error.Normalized.t()}
  def decode(%{} = value) do
    with :ok <- role(value),
         {:ok, content} <- optional_string(Map.get(value, "content"), "content"),
         {:ok, reasoning} <- reasoning(value),
         {:ok, tool_calls} <- tool_calls(Map.get(value, "tool_calls")) do
      {:ok,
       %__MODULE__{
         content: content,
         reasoning: reasoning,
         tool_calls: tool_calls
       }}
    end
  end

  def decode(_value) do
    invalid_delta("Provider stream delta is malformed")
  end

  defp role(value) do
    case Map.get(value, "role") do
      nil -> :ok
      "assistant" -> :ok
      _role -> invalid_delta("Provider stream delta has an invalid role")
    end
  end

  defp optional_string(nil, _field) do
    {:ok, nil}
  end

  defp optional_string(value, field) do
    value
    |> Value.string([field], allow_empty: true)
    |> Protocol.canonical("invalid_stream_delta", "Provider stream delta is malformed")
  end

  defp reasoning(value) do
    reasoning = Map.get(value, "reasoning")
    reasoning_content = Map.get(value, "reasoning_content")
    select_reasoning(reasoning, reasoning_content)
  end

  defp select_reasoning(nil, nil) do
    {:ok, nil}
  end

  defp select_reasoning(value, nil) do
    optional_string(value, "reasoning")
  end

  defp select_reasoning(nil, value) do
    optional_string(value, "reasoning_content")
  end

  defp select_reasoning(_reasoning, _reasoning_content) do
    invalid_delta("Provider stream delta contains ambiguous reasoning fields")
  end

  defp tool_calls(nil) do
    {:ok, nil}
  end

  defp tool_calls(value) when is_list(value) do
    {:ok, value}
  end

  defp tool_calls(_value) do
    invalid_delta("Provider stream tool-call fragments must be a list")
  end

  defp invalid_delta(message) do
    Protocol.error("invalid_stream_delta", message)
  end
end
