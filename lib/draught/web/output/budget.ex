defmodule Draught.Web.Output.Budget do
  @moduledoc """
  Calculates whether a web output envelope fits its JSON byte budget.

  The calculation accounts for JSON escaping and collection separators without
  first allocating the encoded document.
  """

  @short_escapes [8, 9, 10, 12, 13, 34, 92]

  @doc "Checks a JSON value's encoded byte size without allocating its encoded form."
  @spec validate(map() | list() | String.t(), pos_integer()) :: :ok | {:error, :too_large}
  def validate(value, maximum) do
    value
    |> encoded_size()
    |> result(maximum)
  end

  defp encoded_size(value) when is_binary(value) do
    escaped_size(value, 2)
  end

  defp encoded_size(value) when is_list(value) do
    collection_size(value, 2)
  end

  defp encoded_size(value) when is_map(value) do
    entries =
      Enum.sum_by(value, fn {key, item} ->
        encoded_size(key) + 1 + encoded_size(item)
      end)

    entries + separators(map_size(value)) + 2
  end

  defp collection_size([], delimiters) do
    delimiters
  end

  defp collection_size(values, delimiters) do
    delimiters + Enum.sum_by(values, &encoded_size/1) + separators(length(values))
  end

  defp separators(0) do
    0
  end

  defp separators(count) do
    count - 1
  end

  defp escaped_size(<<>>, size) do
    size
  end

  defp escaped_size(<<byte, rest::binary>>, size) when byte in @short_escapes do
    escaped_size(rest, size + 2)
  end

  defp escaped_size(<<byte, rest::binary>>, size) when byte in 0..31 do
    escaped_size(rest, size + 6)
  end

  defp escaped_size(<<_byte, rest::binary>>, size) do
    escaped_size(rest, size + 1)
  end

  defp result(size, maximum) when size <= maximum do
    :ok
  end

  defp result(_size, _maximum) do
    {:error, :too_large}
  end
end
