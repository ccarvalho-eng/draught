defmodule Draught.Provider.OpenAI.Stream.ToolCall.Fragment do
  @moduledoc false

  alias Draught.Provider.OpenAI.Protocol
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @maximum_identity_bytes 256

  @enforce_keys [:index, :arguments]
  defstruct [:index, :id, :type, :name, :arguments]

  @type t :: %__MODULE__{
          index: non_neg_integer(),
          id: String.t() | nil,
          type: String.t() | nil,
          name: String.t() | nil,
          arguments: String.t()
        }

  @doc "Validates one decoded provider tool-call fragment."
  @spec decode(term(), pos_integer()) :: {:ok, t()} | {:error, Draught.Error.Normalized.t()}
  def decode(value, max_calls) do
    with {:ok, attributes} <- normalize(value),
         {:ok, index} <- index(attributes, max_calls),
         {:ok, id} <- optional_identity(attributes, :id),
         {:ok, type} <- type(attributes),
         {:ok, name, arguments} <- function(attributes) do
      {:ok,
       %__MODULE__{
         index: index,
         id: id,
         type: type,
         name: name,
         arguments: arguments
       }}
    end
  end

  defp normalize(value) do
    value
    |> Attributes.normalize([:index, :id, :type, :function])
    |> validation("invalid_tool_call_fragment", "Tool call fragment is invalid")
  end

  defp index(attributes, max_calls) do
    with {:ok, raw_index} <- Attributes.fetch_required(attributes, :index),
         {:ok, index} <- Value.non_negative_integer(raw_index, [:index]) do
      index_result(index, max_calls)
    else
      {:error, %Error{}} = result ->
        validation(result, "invalid_tool_call_fragment", "Tool call index is invalid")
    end
  end

  defp index_result(index, max_calls) when index < max_calls do
    {:ok, index}
  end

  defp index_result(_index, _max_calls) do
    Protocol.error("too_many_tool_calls", "Tool call index exceeds the configured limit")
  end

  defp optional_identity(attributes, key) do
    attributes
    |> Map.get(key)
    |> optional_identity_value(key)
  end

  defp optional_identity_value(nil, _key) do
    {:ok, nil}
  end

  defp optional_identity_value(value, key) do
    with {:ok, identity} <- Value.string(value, [key]),
         true <- byte_size(identity) <= @maximum_identity_bytes do
      {:ok, identity}
    else
      {:error, %Error{}} = result ->
        validation(result, "invalid_tool_call_fragment", "Tool call identity is invalid")

      false ->
        Protocol.error("invalid_tool_call_fragment", "Tool call identity is too large")
    end
  end

  defp type(attributes) do
    case Map.get(attributes, :type) do
      nil -> {:ok, nil}
      "function" -> {:ok, "function"}
      _value -> Protocol.error("invalid_tool_call_fragment", "Tool call type is invalid")
    end
  end

  defp function(attributes) do
    case Map.get(attributes, :function) do
      nil ->
        {:ok, nil, ""}

      value when is_map(value) ->
        decode_function(value)

      _value ->
        Protocol.error("invalid_tool_call_fragment", "Tool call function is invalid")
    end
  end

  defp decode_function(value) do
    with {:ok, attributes} <- normalize_function(value),
         {:ok, name} <- optional_identity(attributes, :name),
         {:ok, arguments} <- arguments(attributes) do
      {:ok, name, arguments}
    end
  end

  defp normalize_function(value) do
    value
    |> Attributes.normalize([:name, :arguments])
    |> validation("invalid_tool_call_fragment", "Tool call function is invalid")
  end

  defp arguments(attributes) do
    case Map.get(attributes, :arguments, "") do
      value when is_binary(value) ->
        {:ok, value}

      _value ->
        Protocol.error("invalid_tool_call_fragment", "Tool call arguments are invalid")
    end
  end

  defp validation(result, code, message) do
    Protocol.canonical(result, code, message)
  end
end
