defmodule Draught.Provider.OpenAI.Stream.ToolCall.Partial do
  @moduledoc """
  Accumulates one indexed streamed tool call until it can be finalized.

  Identity fields may arrive incrementally but cannot change once set. Finalization
  requires complete function identity and a JSON object for arguments.
  """

  alias Draught.Provider.OpenAI.Protocol
  alias Draught.Provider.OpenAI.Stream.ToolCall.Fragment
  alias Draught.Tool.Call

  @enforce_keys [:index, :arguments]
  defstruct [:index, :id, :type, :name, :arguments]

  @type t :: %__MODULE__{
          index: non_neg_integer(),
          id: String.t() | nil,
          type: String.t() | nil,
          name: String.t() | nil,
          arguments: String.t()
        }

  @doc "Initializes assembly state for one provider tool-call index."
  @spec new(non_neg_integer()) :: t()
  def new(index) do
    %__MODULE__{index: index, arguments: ""}
  end

  @doc "Merges a validated fragment while preserving identity invariants."
  @spec merge(t(), Fragment.t()) :: {:ok, t()} | {:error, Draught.Error.Normalized.t()}
  def merge(%__MODULE__{} = partial, %Fragment{} = fragment) do
    with {:ok, id} <- merge_identity(partial.id, fragment.id),
         {:ok, type} <- merge_identity(partial.type, fragment.type),
         {:ok, name} <- merge_identity(partial.name, fragment.name) do
      {:ok,
       %__MODULE__{
         partial
         | id: id,
           type: type,
           name: name,
           arguments: partial.arguments <> fragment.arguments
       }}
    end
  end

  @doc "Converts complete assembly state into a provider-neutral tool call."
  @spec finalize(t()) :: {:ok, Call.t()} | {:error, Draught.Error.Normalized.t()}
  def finalize(%__MODULE__{} = partial) do
    with :ok <- complete?(partial),
         {:ok, arguments} <- decode_arguments(partial.arguments) do
      build_call(partial, arguments)
    end
  end

  defp merge_identity(current, nil) do
    {:ok, current}
  end

  defp merge_identity(nil, incoming) do
    {:ok, incoming}
  end

  defp merge_identity(value, value) do
    {:ok, value}
  end

  defp merge_identity(_current, _incoming) do
    Protocol.error("conflicting_tool_call", "Tool call identity changed during streaming")
  end

  defp complete?(%__MODULE__{id: id, type: "function", name: name})
       when is_binary(id) and is_binary(name) do
    :ok
  end

  defp complete?(_partial) do
    Protocol.error("invalid_tool_call", "Tool call identity is incomplete")
  end

  defp decode_arguments(encoded) do
    case Jason.decode(encoded) do
      {:ok, arguments} when is_map(arguments) ->
        {:ok, arguments}

      {:ok, _arguments} ->
        Protocol.error("invalid_tool_call", "Tool call arguments must be a JSON object")

      {:error, _reason} ->
        Protocol.error("invalid_tool_call", "Tool call arguments contain invalid JSON")
    end
  end

  defp build_call(partial, arguments) do
    [id: partial.id, name: partial.name, arguments: arguments]
    |> Call.new()
    |> Protocol.canonical("invalid_tool_call", "Tool call is invalid")
  end
end
