defmodule Draught.CLI.UI.Owl.JSON do
  @moduledoc """
  Renders validated approval JSON as bounded, deterministic terminal data.

  Values are decoded before styling and encoded again with JSON escaping, so
  operation text cannot introduce terminal control sequences. Rendering never
  truncates a value: excessive depth or output size makes the view unavailable.
  """

  alias Draught.CLI.UI.Owl.BoundedStyle

  @maximum_bytes 65_536
  @maximum_depth 32
  @maximum_preview_bytes 16_384

  @doc "Pretty-prints one JSON object with optional trusted ANSI token styling."
  @spec render(binary(), boolean()) :: {:ok, iodata()} | {:error, :unavailable}
  def render(preview, styled?)
      when is_binary(preview) and byte_size(preview) <= @maximum_preview_bytes and
             is_boolean(styled?) do
    with {:ok, decoded} <- Jason.decode(preview),
         true <- is_map(decoded),
         {:ok, plain} <- value(decoded, 0, false),
         true <- within_limit?(plain) do
      styled_result(decoded, plain, styled?)
    else
      _failure -> {:error, :unavailable}
    end
  end

  def render(_preview, _styled?) do
    {:error, :unavailable}
  end

  defp value(_value, depth, _styled?) when depth > @maximum_depth do
    {:error, :unavailable}
  end

  defp value(value, depth, styled?) when is_map(value) do
    map_value(value, depth, styled?)
  end

  defp value(value, depth, styled?) when is_list(value) do
    list_value(value, depth, styled?)
  end

  defp value(value, _depth, styled?) when is_binary(value) do
    scalar(value, :green, styled?)
  end

  defp value(value, _depth, styled?) when is_number(value) do
    scalar(value, :magenta, styled?)
  end

  defp value(value, _depth, styled?) when value in [true, false] do
    scalar(value, :yellow, styled?)
  end

  defp value(nil, _depth, styled?) do
    scalar(nil, :light_black, styled?)
  end

  defp map_value(value, _depth, _styled?) when map_size(value) == 0 do
    {:ok, "{}"}
  end

  defp map_value(value, depth, styled?) do
    value
    |> Enum.sort_by(fn {key, _value} -> key end)
    |> map_entries(depth + 1, styled?, [])
    |> collection("{", "}", depth)
  end

  defp list_value([], _depth, _styled?) do
    {:ok, "[]"}
  end

  defp list_value(value, depth, styled?) do
    value
    |> list_entries(depth + 1, styled?, [])
    |> collection("[", "]", depth)
  end

  defp map_entries([], _depth, _styled?, entries) do
    {:ok, Enum.reverse(entries)}
  end

  defp map_entries([{key, value} | rest], depth, styled?, entries) when is_binary(key) do
    with {:ok, encoded_key} <- encode(key),
         {:ok, rendered_value} <- value(value, depth, styled?) do
      entry = [indent(depth), token(encoded_key, :cyan, styled?), ": ", rendered_value]
      map_entries(rest, depth, styled?, [entry | entries])
    end
  end

  defp map_entries(_entries, _depth, _styled?, _rendered) do
    {:error, :unavailable}
  end

  defp list_entries([], _depth, _styled?, entries) do
    {:ok, Enum.reverse(entries)}
  end

  defp list_entries([value | rest], depth, styled?, entries) do
    with {:ok, rendered} <- value(value, depth, styled?) do
      list_entries(rest, depth, styled?, [[indent(depth), rendered] | entries])
    end
  end

  defp collection({:ok, entries}, opening, closing, depth) do
    {:ok, [opening, "\n", Enum.intersperse(entries, ",\n"), "\n", indent(depth), closing]}
  end

  defp collection({:error, :unavailable}, _opening, _closing, _depth) do
    {:error, :unavailable}
  end

  defp scalar(value, colour, styled?) do
    with {:ok, encoded} <- encode(value) do
      {:ok, token(encoded, colour, styled?)}
    end
  end

  defp encode(value) do
    Jason.encode_to_iodata(value, escape: :unicode_safe)
  end

  defp token(content, colour, true) do
    IO.ANSI.format([colour, content, :reset], true)
  end

  defp token(content, _colour, false) do
    content
  end

  defp styled_result(_decoded, plain, false) do
    {:ok, plain}
  end

  defp styled_result(decoded, plain, true) do
    case value(decoded, 0, true) do
      {:ok, styled} -> BoundedStyle.choose(styled, plain, @maximum_bytes)
      {:error, :unavailable} -> {:ok, plain}
    end
  end

  defp within_limit?(content) do
    IO.iodata_length(content) <= @maximum_bytes
  end

  defp indent(depth) do
    String.duplicate("  ", depth)
  end
end
