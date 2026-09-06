defmodule Draught.Provider.Options do
  @moduledoc """
  Provider-neutral generation options.

  Omitted values remain `nil` so an adapter can apply its documented defaults.
  """

  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  defstruct temperature: nil, max_output_tokens: nil, stop: [], seed: nil

  @type t :: %__MODULE__{
          temperature: number() | nil,
          max_output_tokens: pos_integer() | nil,
          stop: [String.t()],
          seed: integer() | nil
        }

  @doc "Builds validated provider-neutral generation options."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes \\ %{}) do
    with {:ok, normalized} <-
           Attributes.normalize(attributes, [:temperature, :max_output_tokens, :stop, :seed]),
         {:ok, temperature} <- temperature(normalized),
         {:ok, max_output_tokens} <- max_output_tokens(normalized),
         {:ok, stop} <- stop(normalized),
         {:ok, seed} <- seed(normalized) do
      {:ok,
       %__MODULE__{
         temperature: temperature,
         max_output_tokens: max_output_tokens,
         stop: stop,
         seed: seed
       }}
    end
  end

  defp temperature(attributes) do
    case Map.fetch(attributes, :temperature) do
      {:ok, nil} -> {:ok, nil}
      {:ok, value} -> Value.number_in_range(value, 0, 2, [:temperature])
      :error -> {:ok, nil}
    end
  end

  defp max_output_tokens(attributes) do
    case Map.fetch(attributes, :max_output_tokens) do
      {:ok, nil} -> {:ok, nil}
      {:ok, value} -> Value.positive_integer(value, [:max_output_tokens])
      :error -> {:ok, nil}
    end
  end

  defp stop(attributes) do
    case Map.get(attributes, :stop, []) do
      values when is_list(values) -> validate_stop_values(values)
      _value -> Error.single([:stop], :invalid_type, "must be a list")
    end
  end

  defp validate_stop_values(values) do
    values
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {value, index}, {:ok, valid_values} ->
      case Value.string(value, [:stop, index]) do
        {:ok, valid_value} -> {:cont, {:ok, [valid_value | valid_values]}}
        {:error, _error} = result -> {:halt, result}
      end
    end)
    |> reverse_values()
  end

  defp reverse_values({:ok, values}) do
    {:ok, Enum.reverse(values)}
  end

  defp reverse_values({:error, _error} = result) do
    result
  end

  defp seed(attributes) do
    case Map.fetch(attributes, :seed) do
      {:ok, nil} -> {:ok, nil}
      {:ok, value} when is_integer(value) -> {:ok, value}
      {:ok, _value} -> Error.single([:seed], :invalid_type, "must be an integer")
      :error -> {:ok, nil}
    end
  end
end
