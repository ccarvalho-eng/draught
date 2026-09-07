defmodule Draught.Conversation.Interchange.Text.Decoder.JSON do
  @moduledoc """
  Decodes text-extension JSON under structural safety limits.

  A pre-scan bounds nesting and structural tokens before allocation. Ordered
  objects are then normalized while rejecting duplicate keys at every depth.
  """

  alias Draught.Validation.Error
  alias Jason.OrderedObject

  @maximum_depth 32
  @maximum_structural_tokens 262_144

  @doc "Checks structural depth before decoding extension JSON."
  @spec decode(binary()) :: Error.result(term())
  def decode(encoded) do
    with :ok <- scan(encoded, 0, 0, false, false) do
      decode_checked(encoded)
    end
  end

  defp scan(<<>>, _depth, _tokens, _inside_string, _escaped) do
    :ok
  end

  defp scan(<<_byte, rest::binary>>, depth, tokens, true, true) do
    scan(rest, depth, tokens, true, false)
  end

  defp scan(<<?\\, rest::binary>>, depth, tokens, true, false) do
    scan(rest, depth, tokens, true, true)
  end

  defp scan(<<?\", rest::binary>>, depth, tokens, true, false) do
    scan(rest, depth, tokens, false, false)
  end

  defp scan(<<_byte, rest::binary>>, depth, tokens, true, false) do
    scan(rest, depth, tokens, true, false)
  end

  defp scan(<<?\", rest::binary>>, depth, tokens, false, false) do
    scan(rest, depth, tokens, true, false)
  end

  defp scan(<<byte, rest::binary>>, depth, tokens, false, false) when byte in ~c"[{" do
    next_depth = depth + 1
    scan_nested(rest, next_depth, tokens + 1)
  end

  defp scan(<<byte, rest::binary>>, depth, tokens, false, false) when byte in ~c"]}" do
    scan(rest, max(depth - 1, 0), tokens, false, false)
  end

  defp scan(<<?,, rest::binary>>, depth, tokens, false, false) do
    scan_nested(rest, depth, tokens + 1)
  end

  defp scan(<<_byte, rest::binary>>, depth, tokens, false, false) do
    scan(rest, depth, tokens, false, false)
  end

  defp scan_nested(rest, depth, tokens)
       when depth <= @maximum_depth and tokens <= @maximum_structural_tokens do
    scan(rest, depth, tokens, false, false)
  end

  defp scan_nested(_rest, depth, _tokens) when depth > @maximum_depth do
    Error.single([], :too_deep, "extension JSON exceeds the maximum nesting depth")
  end

  defp scan_nested(_rest, _depth, _tokens) do
    Error.single([], :too_large, "extension JSON exceeds the structural token limit")
  end

  defp decode_checked(encoded) do
    case Jason.decode(encoded, objects: :ordered_objects) do
      {:ok, value} -> normalize(value, [])
      {:error, _reason} -> Error.single([], :invalid_format, "has invalid extension JSON")
    end
  end

  defp normalize(%OrderedObject{values: entries}, path) do
    with :ok <- unique_keys(entries, path) do
      Enum.reduce_while(entries, {:ok, %{}}, fn entry, result ->
        normalize_object_entry(entry, result, path)
      end)
    end
  end

  defp normalize(values, path) when is_list(values) do
    values
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn entry, result ->
      normalize_list_entry(entry, result, path)
    end)
    |> reverse_values()
  end

  defp normalize(value, _path) do
    {:ok, value}
  end

  defp normalize_object_entry({key, value}, {:ok, normalized}, path) do
    case normalize(value, Enum.concat(path, [key])) do
      {:ok, item} -> {:cont, {:ok, Map.put(normalized, key, item)}}
      {:error, %Error{}} = result -> {:halt, result}
    end
  end

  defp normalize_list_entry({value, index}, {:ok, normalized}, path) do
    case normalize(value, Enum.concat(path, [index])) do
      {:ok, item} -> {:cont, {:ok, [item | normalized]}}
      {:error, %Error{}} = result -> {:halt, result}
    end
  end

  defp unique_keys(entries, path) do
    entries
    |> Enum.map(fn {key, _value} -> key end)
    |> duplicate_key()
    |> duplicate_result(path)
  end

  defp duplicate_key(keys) do
    Enum.reduce_while(keys, MapSet.new(), fn key, seen ->
      seen
      |> MapSet.member?(key)
      |> duplicate_membership(key, seen)
    end)
  end

  defp duplicate_membership(true, key, _seen) do
    {:halt, {:duplicate, key}}
  end

  defp duplicate_membership(false, key, seen) do
    {:cont, MapSet.put(seen, key)}
  end

  defp duplicate_result({:duplicate, key}, path) do
    path
    |> Enum.concat([key])
    |> Error.single(:duplicate_key, "must appear only once")
  end

  defp duplicate_result(%MapSet{}, _path) do
    :ok
  end

  defp reverse_values({:ok, values}) do
    {:ok, Enum.reverse(values)}
  end

  defp reverse_values({:error, %Error{}} = result) do
    result
  end
end
