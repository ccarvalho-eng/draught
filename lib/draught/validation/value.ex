defmodule Draught.Validation.Value do
  @moduledoc """
  Validates common scalar values for namespaced contract constructors.
  """

  alias Draught.Validation.Attributes
  alias Draught.Validation.Error

  @doc "Fetches and validates a required UTF-8 string."
  @spec required_string(map(), atom(), keyword()) :: Error.result(String.t())
  def required_string(attributes, key, options \\ []) do
    with {:ok, value} <- Attributes.fetch_required(attributes, key) do
      string(value, [key], options)
    end
  end

  @doc "Validates a UTF-8 string, optionally allowing an empty value."
  @spec string(term(), [term()], keyword()) :: Error.result(String.t())
  def string(value, path, options \\ []) do
    allow_empty = Keyword.get(options, :allow_empty, false)

    value
    |> valid_string?(allow_empty)
    |> string_result(value, path)
  end

  @doc "Validates a boolean."
  @spec boolean(term(), [term()]) :: Error.result(boolean())
  def boolean(value, _path) when is_boolean(value) do
    {:ok, value}
  end

  def boolean(_value, path) do
    Error.single(path, :invalid_type, "must be a boolean")
  end

  @doc "Validates a non-negative integer."
  @spec non_negative_integer(term(), [term()]) :: Error.result(non_neg_integer())
  def non_negative_integer(value, _path) when is_integer(value) and value >= 0 do
    {:ok, value}
  end

  def non_negative_integer(_value, path) do
    Error.single(path, :invalid_value, "must be a non-negative integer")
  end

  @doc "Validates a positive integer."
  @spec positive_integer(term(), [term()]) :: Error.result(pos_integer())
  def positive_integer(value, _path) when is_integer(value) and value > 0 do
    {:ok, value}
  end

  def positive_integer(_value, path) do
    Error.single(path, :invalid_value, "must be a positive integer")
  end

  @doc "Validates a positive integer that does not exceed an inclusive maximum."
  @spec positive_integer_at_most(term(), pos_integer(), [term()]) ::
          Error.result(pos_integer())
  def positive_integer_at_most(value, maximum, _path)
      when is_integer(value) and value > 0 and value <= maximum do
    {:ok, value}
  end

  def positive_integer_at_most(_value, maximum, path) do
    Error.single(path, :invalid_value, "must be a positive integer not greater than #{maximum}")
  end

  @doc "Validates a finite number inside an inclusive range."
  @spec number_in_range(term(), number(), number(), [term()]) :: Error.result(number())
  def number_in_range(value, minimum, maximum, _path)
      when is_number(value) and value >= minimum and value <= maximum do
    {:ok, value}
  end

  def number_in_range(_value, minimum, maximum, path) do
    Error.single(path, :invalid_value, "must be a number from #{minimum} to #{maximum}")
  end

  @doc "Normalizes an atom or string against a closed atom set."
  @spec enum(term(), [atom()], [term()]) :: Error.result(atom())
  def enum(value, allowed, path) when is_list(allowed) do
    normalized =
      Enum.find(allowed, fn allowed_value ->
        value == allowed_value or value == Atom.to_string(allowed_value)
      end)

    case normalized do
      nil -> Error.single(path, :invalid_value, "is not a supported value")
      matched -> {:ok, matched}
    end
  end

  defp valid_string?(value, allow_empty) do
    is_binary(value) and String.valid?(value) and (allow_empty or byte_size(value) > 0)
  end

  defp string_result(true, value, _path) do
    {:ok, value}
  end

  defp string_result(false, _value, path) do
    Error.single(path, :invalid_value, "must be a valid UTF-8 string")
  end
end
