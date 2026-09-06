defmodule Draught.Validation.JSON do
  @moduledoc """
  Validates bounded JSON-compatible values without depending on a JSON codec.
  """

  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @max_depth 16
  @max_collection_entries 1_000
  @max_external_bytes 4_194_304
  @max_key_bytes 256
  @max_string_bytes 1_048_576

  @type value :: nil | boolean() | number() | String.t() | [value()] | %{String.t() => value()}

  @doc "Validates a JSON-compatible value at the supplied error path."
  @spec validate(term(), [term()]) :: :ok | {:error, Error.t()}
  def validate(value, path \\ []) do
    with :ok <- validate_external_size(value, path) do
      validate_value(value, path, @max_depth)
    end
  end

  @doc "Validates a JSON-compatible object with binary keys."
  @spec validate_object(term(), [term()]) :: :ok | {:error, Error.t()}
  def validate_object(value, path \\ [])

  def validate_object(value, path) when is_map(value) do
    validate(value, path)
  end

  def validate_object(_value, path) do
    Error.single(path, :invalid_type, "must be a JSON object")
  end

  defp validate_value(_value, path, 0) do
    Error.single(path, :too_deep, "exceeds the maximum nesting depth")
  end

  defp validate_value(value, _path, _depth)
       when is_nil(value) or is_boolean(value) or is_number(value) do
    :ok
  end

  defp validate_value(value, path, _depth) when is_binary(value) do
    with {:ok, string} <- Value.string(value, path, allow_empty: true) do
      validate_string_size(string, path)
    end
  end

  defp validate_value(value, path, depth) when is_list(value) do
    with :ok <- validate_collection_size(value, path) do
      validate_list(value, path, depth)
    end
  end

  defp validate_value(value, path, depth) when is_map(value) do
    with :ok <- validate_collection_size(value, path),
         :ok <- validate_object_keys(value, path) do
      value
      |> Enum.sort_by(fn {key, _item} -> key end)
      |> Enum.reduce_while(:ok, fn {key, item}, :ok ->
        validate_object_entry(key, item, path, depth)
      end)
    end
  end

  defp validate_value(_value, path, _depth) do
    Error.single(path, :invalid_type, "must be JSON-compatible")
  end

  defp validate_list(value, path, depth) do
    value
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {item, index}, :ok ->
      case validate_value(item, Enum.concat(path, [index]), depth - 1) do
        :ok -> {:cont, :ok}
        {:error, _error} = result -> {:halt, result}
      end
    end)
  end

  defp validate_object_keys(value, path) do
    value
    |> Enum.all?(fn {key, _item} -> is_binary(key) end)
    |> object_keys_result(path)
  end

  defp object_keys_result(true, _path) do
    :ok
  end

  defp object_keys_result(false, path) do
    invalid_path = Enum.concat(path, [:unknown])
    Error.single(invalid_path, :invalid_type, "object keys must be strings")
  end

  defp validate_object_entry(key, item, path, depth) do
    item_path = Enum.concat(path, [key])

    with {:ok, valid_key} <- Value.string(key, item_path, allow_empty: true),
         :ok <- validate_key_size(valid_key, item_path) do
      validate_object_value(item, item_path, depth)
    else
      {:error, _error} = result -> {:halt, result}
    end
  end

  defp validate_object_value(item, path, depth) do
    case validate_value(item, path, depth - 1) do
      :ok -> {:cont, :ok}
      {:error, _error} = result -> {:halt, result}
    end
  end

  defp validate_external_size(value, path) do
    value
    |> :erlang.external_size()
    |> within_limit?(@max_external_bytes)
    |> size_result(path, "exceeds the maximum aggregate size")
  end

  defp validate_collection_size(value, path) do
    value
    |> Enum.count()
    |> within_limit?(@max_collection_entries)
    |> size_result(path, "exceeds the maximum collection size")
  end

  defp validate_string_size(value, path) do
    value
    |> byte_size()
    |> within_limit?(@max_string_bytes)
    |> size_result(path, "exceeds the maximum string size")
  end

  defp validate_key_size(value, path) do
    value
    |> byte_size()
    |> within_limit?(@max_key_bytes)
    |> size_result(path, "exceeds the maximum object-key size")
  end

  defp within_limit?(size, limit) do
    size <= limit
  end

  defp size_result(true, _path, _message) do
    :ok
  end

  defp size_result(false, path, message) do
    Error.single(path, :too_large, message)
  end
end
