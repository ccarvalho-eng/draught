defmodule Draught.CLI.Configuration.Decoder.Normalizer do
  @moduledoc """
  Normalizes decoded JSON maps into the closed configuration keys accepted by Draught.
  """

  alias Draught.CLI.Configuration.Error
  alias Draught.CLI.Configuration.Source

  @max_depth 8
  @max_nodes 256
  @max_key_bytes 64
  @max_string_bytes 8_192

  @doc "Normalizes decoded JSON while enforcing depth, size, and duplicate-key limits."
  @spec normalize(Source.kind(), term()) :: Error.result(map())
  def normalize(source, value) do
    with {:ok, normalized, _remaining} <-
           normalize_value(value, source, [], @max_depth, @max_nodes),
         true <- is_map(normalized) do
      {:ok, normalized}
    else
      false -> Error.new(source, [], :invalid_type, "must contain a JSON object")
      {:error, %Error{}} = result -> result
    end
  end

  defp normalize_value(_value, source, path, 0, _remaining) do
    Error.new(source, path, :too_deep, "exceeds the maximum nesting depth")
  end

  defp normalize_value(_value, source, path, _depth, 0) do
    Error.new(source, path, :too_large, "exceeds the maximum structural size")
  end

  defp normalize_value(%Jason.OrderedObject{values: pairs}, source, path, depth, remaining) do
    normalize_pairs(pairs, source, path, depth, remaining - 1, %{})
  end

  defp normalize_value(values, source, path, depth, remaining) when is_list(values) do
    normalize_list(values, source, path, depth, remaining - 1, [], 0)
  end

  defp normalize_value(value, source, path, _depth, remaining) when is_binary(value) do
    valid = byte_size(value) <= @max_string_bytes and String.valid?(value)
    string_result(valid, value, source, path, remaining)
  end

  defp normalize_value(value, _source, _path, _depth, remaining)
       when is_nil(value) or is_boolean(value) or is_number(value) do
    {:ok, value, remaining - 1}
  end

  defp normalize_pairs([], _source, _path, _depth, remaining, normalized) do
    {:ok, normalized, remaining}
  end

  defp normalize_pairs([{key, value} | rest], source, path, depth, remaining, normalized) do
    with :ok <- validate_key(key, source, path),
         :ok <- reject_duplicate(key, normalized, source, path),
         {:ok, item, next_remaining} <-
           normalize_value(value, source, path_for(key, path), depth - 1, remaining) do
      updated = Map.put(normalized, key, item)
      normalize_pairs(rest, source, path, depth, next_remaining, updated)
    end
  end

  defp normalize_list([], _source, _path, _depth, remaining, values, _index) do
    {:ok, Enum.reverse(values), remaining}
  end

  defp normalize_list([value | rest], source, path, depth, remaining, values, index) do
    with {:ok, item, next_remaining} <-
           normalize_value(value, source, Enum.concat(path, [index]), depth - 1, remaining) do
      normalize_list(rest, source, path, depth, next_remaining, [item | values], index + 1)
    end
  end

  defp validate_key(key, _source, _path)
       when is_binary(key) and byte_size(key) > 0 and byte_size(key) <= @max_key_bytes do
    :ok
  end

  defp validate_key(_key, source, path) do
    Error.new(source, safe_path(path), :invalid_value, "contains an invalid object key")
  end

  defp reject_duplicate(key, values, source, path) do
    values
    |> Map.has_key?(key)
    |> duplicate_result(source, path)
  end

  defp string_result(true, value, _source, _path, remaining) do
    {:ok, value, remaining - 1}
  end

  defp string_result(false, _value, source, path, _remaining) do
    Error.new(source, path, :too_large, "contains an invalid or oversized string")
  end

  defp duplicate_result(true, source, path) do
    Error.new(source, safe_path(path), :duplicate_key, "contains a duplicate object key")
  end

  defp duplicate_result(false, _source, _path) do
    :ok
  end

  defp path_for(key, path) do
    case known_key(key) do
      nil -> safe_path(path)
      segment -> Enum.concat(path, [segment])
    end
  end

  defp safe_path(path) do
    Enum.filter(path, fn segment -> is_atom(segment) or is_integer(segment) end)
  end

  defp known_key("profile"), do: :profile
  defp known_key("model"), do: :model
  defp known_key("web"), do: :web
  defp known_key("risk"), do: :risk
  defp known_key("profiles"), do: :profiles
  defp known_key("provider"), do: :provider
  defp known_key("base_url"), do: :base_url
  defp known_key("credential_env"), do: :credential_env
  defp known_key("headers"), do: :headers
  defp known_key(_key), do: nil
end
