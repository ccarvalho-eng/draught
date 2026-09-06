defmodule Draught.Provider.OpenAI.Stream.ToolCalls do
  @moduledoc false

  alias Draught.Provider.OpenAI.Protocol
  alias Draught.Provider.OpenAI.Stream.ToolCall.Fragment
  alias Draught.Provider.OpenAI.Stream.ToolCall.Partial
  alias Draught.Provider.OpenAI.Stream.ToolCalls.Configuration

  @enforce_keys [:partials, :argument_bytes, :max_calls, :max_arguments_bytes]
  defstruct [:partials, :argument_bytes, :max_calls, :max_arguments_bytes]

  @type t :: %__MODULE__{
          partials: %{non_neg_integer() => Partial.t()},
          argument_bytes: non_neg_integer(),
          max_calls: pos_integer(),
          max_arguments_bytes: pos_integer()
        }

  @doc "Initializes bounded streamed tool-call assembly state."
  @spec new(map() | keyword()) :: {:ok, t()} | {:error, Draught.Error.Normalized.t()}
  def new(options \\ []) do
    with {:ok, configuration} <- Configuration.new(options) do
      {:ok,
       %__MODULE__{
         partials: %{},
         argument_bytes: 0,
         max_calls: configuration.max_calls,
         max_arguments_bytes: configuration.max_arguments_bytes
       }}
    end
  end

  @doc "Appends decoded provider fragments to the immutable assembly state."
  @spec append(t(), nil | [term()]) :: {:ok, t()} | {:error, Draught.Error.Normalized.t()}
  def append(%__MODULE__{} = state, nil) do
    {:ok, state}
  end

  def append(%__MODULE__{} = state, fragments) when is_list(fragments) do
    Enum.reduce_while(fragments, {:ok, state}, &append_fragment/2)
  end

  def append(%__MODULE__{}, _fragments) do
    Protocol.error("invalid_tool_call_fragment", "Tool call fragments must be a list")
  end

  @doc "Finalizes indexed fragments as ordered provider-neutral tool calls."
  @spec finalize(t()) ::
          {:ok, [Draught.Tool.Call.t()]} | {:error, Draught.Error.Normalized.t()}
  def finalize(%__MODULE__{partials: partials}) when map_size(partials) == 0 do
    {:ok, []}
  end

  def finalize(%__MODULE__{partials: partials}) do
    with {:ok, ordered} <- ordered_partials(partials),
         {:ok, calls} <- finalize_partials(ordered),
         :ok <- unique_ids?(calls) do
      {:ok, calls}
    end
  end

  defp append_fragment(fragment, {:ok, state}) do
    case append_one(state, fragment) do
      {:ok, updated} -> {:cont, {:ok, updated}}
      {:error, _error} = result -> {:halt, result}
    end
  end

  defp append_one(%__MODULE__{} = state, value) do
    with {:ok, fragment} <- Fragment.decode(value, state.max_calls),
         {:ok, argument_bytes} <- retained_bytes(state, fragment),
         {:ok, partial} <- merge_partial(state, fragment) do
      {:ok,
       %__MODULE__{
         state
         | partials: Map.put(state.partials, fragment.index, partial),
           argument_bytes: argument_bytes
       }}
    end
  end

  defp retained_bytes(state, fragment) do
    retained = state.argument_bytes + byte_size(fragment.arguments)
    retained_result(retained <= state.max_arguments_bytes, retained)
  end

  defp retained_result(true, retained) do
    {:ok, retained}
  end

  defp retained_result(false, _retained) do
    Protocol.error(
      "tool_arguments_too_large",
      "Tool call arguments exceed the configured limit"
    )
  end

  defp merge_partial(state, fragment) do
    state.partials
    |> Map.get(fragment.index, Partial.new(fragment.index))
    |> Partial.merge(fragment)
  end

  defp ordered_partials(partials) do
    indexes =
      partials
      |> Map.keys()
      |> Enum.sort()

    expected = Enum.to_list(0..(map_size(partials) - 1))
    ordered_partials_result(indexes == expected, indexes, partials)
  end

  defp ordered_partials_result(true, indexes, partials) do
    {:ok, Enum.map(indexes, &Map.fetch!(partials, &1))}
  end

  defp ordered_partials_result(false, _indexes, _partials) do
    Protocol.error("invalid_tool_call_sequence", "Tool call indexes are not contiguous")
  end

  defp finalize_partials(partials) do
    result =
      Enum.reduce_while(partials, {:ok, []}, fn partial, {:ok, calls} ->
        case Partial.finalize(partial) do
          {:ok, call} -> {:cont, {:ok, [call | calls]}}
          {:error, _error} = error -> {:halt, error}
        end
      end)

    reverse_calls(result)
  end

  defp reverse_calls({:ok, calls}) do
    {:ok, Enum.reverse(calls)}
  end

  defp reverse_calls({:error, _error} = result) do
    result
  end

  defp unique_ids?(calls) do
    ids = Enum.map(calls, & &1.id)

    unique_count =
      ids
      |> MapSet.new()
      |> MapSet.size()

    unique_ids_result(unique_count == length(ids))
  end

  defp unique_ids_result(true) do
    :ok
  end

  defp unique_ids_result(false) do
    Protocol.error("invalid_tool_call", "Tool call identifiers must be unique")
  end
end
