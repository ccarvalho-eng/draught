defmodule Draught.CLI.UI.Owl.Diff do
  @moduledoc """
  Renders bounded file-replacement previews without reading the workspace.

  Diff content comes only from already validated operation metadata. File text
  is JSON-escaped before display, preventing control characters from becoming
  terminal instructions. Oversized or malformed views are never truncated.
  """

  alias Draught.CLI.UI.Owl.BoundedStyle

  @maximum_bytes 32_768

  @doc "Renders the exact expected and replacement fragments for `replace_in_file`."
  @spec replace_in_file(map(), boolean()) :: {:ok, iodata()} | :unavailable
  def replace_in_file(
        %{"expected" => expected, "path" => path, "replacement" => replacement},
        styled?
      )
      when is_binary(expected) and is_binary(path) and is_binary(replacement) and
             is_boolean(styled?) do
    with {:ok, plain} <- diff(path, expected, replacement, false),
         true <- within_limit?(plain) do
      styled_result(path, expected, replacement, plain, styled?)
    else
      _failure -> :unavailable
    end
  end

  def replace_in_file(_operation, _styled?) do
    :unavailable
  end

  defp diff(path, expected, replacement, styled?) do
    with {:ok, safe_path} <- escaped(path),
         {:ok, removed} <- lines(expected, "-", :red, styled?),
         {:ok, added} <- lines(replacement, "+", :green, styled?) do
      {:ok,
       [
         token("---", :red, styled?),
         " a/",
         safe_path,
         "\n",
         token("+++", :green, styled?),
         " b/",
         safe_path,
         "\n",
         token("@@ exact replacement @@", :cyan, styled?),
         "\n",
         removed,
         added
       ]}
    end
  end

  defp lines(value, prefix, colour, styled?) do
    value
    |> String.split("\n", trim: false)
    |> Enum.reduce_while({:ok, []}, fn line, {:ok, rendered} ->
      case escaped(line) do
        {:ok, safe} ->
          entry = [token(prefix, colour, styled?), " ", safe, "\n"]
          {:cont, {:ok, [entry | rendered]}}

        {:error, :unavailable} = error ->
          {:halt, error}
      end
    end)
    |> reverse_lines()
  end

  defp reverse_lines({:ok, lines}) do
    {:ok, Enum.reverse(lines)}
  end

  defp reverse_lines({:error, :unavailable} = error) do
    error
  end

  defp escaped(value) do
    with {:ok, encoded} <- Jason.encode(value, escape: :unicode_safe),
         true <- byte_size(encoded) >= 2 do
      {:ok, binary_part(encoded, 1, byte_size(encoded) - 2)}
    else
      _failure -> {:error, :unavailable}
    end
  end

  defp token(content, colour, true) do
    IO.ANSI.format([colour, content, :reset], true)
  end

  defp token(content, _colour, false) do
    content
  end

  defp styled_result(_path, _expected, _replacement, plain, false) do
    {:ok, plain}
  end

  defp styled_result(path, expected, replacement, plain, true) do
    case diff(path, expected, replacement, true) do
      {:ok, styled} -> BoundedStyle.choose(styled, plain, @maximum_bytes)
      {:error, :unavailable} -> {:ok, plain}
    end
  end

  defp within_limit?(content) do
    IO.iodata_length(content) <= @maximum_bytes
  end
end
