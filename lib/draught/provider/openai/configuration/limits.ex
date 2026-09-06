defmodule Draught.Provider.OpenAI.Configuration.Limits do
  @moduledoc """
  Bounded response and stream retention limits for the provider runtime.
  """

  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @keys [
    :max_response_bytes,
    :max_event_bytes,
    :max_output_bytes,
    :max_output_fragments,
    :max_calls,
    :max_arguments_bytes
  ]

  @bounds %{
    max_response_bytes: {16_777_216, 67_108_864},
    max_event_bytes: {1_048_576, 8_388_608},
    max_output_bytes: {16_777_216, 67_108_864},
    max_output_fragments: {65_536, 1_048_576},
    max_calls: {128, 1_024},
    max_arguments_bytes: {4_194_304, 8_388_608}
  }

  defstruct max_response_bytes: 16_777_216,
            max_event_bytes: 1_048_576,
            max_output_bytes: 16_777_216,
            max_output_fragments: 65_536,
            max_calls: 128,
            max_arguments_bytes: 4_194_304

  @type t :: %__MODULE__{
          max_response_bytes: pos_integer(),
          max_event_bytes: pos_integer(),
          max_output_bytes: pos_integer(),
          max_output_fragments: pos_integer(),
          max_calls: pos_integer(),
          max_arguments_bytes: pos_integer()
        }

  @doc "Builds validated limits from bounded positive integers."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes \\ %{}) do
    with {:ok, normalized} <- normalize(attributes),
         {:ok, values} <- validate_values(normalized) do
      {:ok, struct!(__MODULE__, values)}
    end
  end

  defp normalize(%__MODULE__{} = limits) do
    {:ok, Map.from_struct(limits)}
  end

  defp normalize(attributes) do
    Attributes.normalize(attributes, @keys)
  end

  defp validate_values(attributes) do
    Enum.reduce_while(@keys, {:ok, %{}}, fn key, {:ok, values} ->
      case bounded_value(attributes, key) do
        {:ok, value} -> {:cont, {:ok, Map.put(values, key, value)}}
        {:error, _error} = result -> {:halt, result}
      end
    end)
  end

  defp bounded_value(attributes, key) do
    {default, maximum} = Map.fetch!(@bounds, key)
    value = Map.get(attributes, key, default)

    value
    |> Value.positive_integer([key])
    |> maximum_result(key, maximum)
  end

  defp maximum_result({:ok, value}, _key, maximum) when value <= maximum do
    {:ok, value}
  end

  defp maximum_result({:ok, _value}, key, maximum) do
    Error.single([key], :invalid_value, "must not exceed #{maximum}")
  end

  defp maximum_result({:error, %Error{}} = result, _key, _maximum) do
    result
  end
end
