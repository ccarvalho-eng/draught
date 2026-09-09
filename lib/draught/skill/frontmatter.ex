defmodule Draught.Skill.Frontmatter do
  @moduledoc """
  Parses the bounded scalar subset of YAML frontmatter used by Draught skills.

  Required and optional scalar fields remain strings. Nested YAML, aliases,
  tags, interpolation, and executable values are intentionally unsupported.
  """

  @doc "Separates frontmatter fields from a Markdown body."
  @spec parse(term()) ::
          {:ok, %{optional(String.t()) => String.t()}, String.t()}
          | {:error, :invalid_frontmatter}
  def parse(content) when is_binary(content) do
    content
    |> normalize_lines()
    |> split()
  end

  def parse(_content) do
    {:error, :invalid_frontmatter}
  end

  defp normalize_lines(content) do
    String.replace(content, "\r\n", "\n")
  end

  defp split("---\n" <> content) do
    case String.split(content, "\n---\n", parts: 2) do
      [frontmatter, body] -> fields(frontmatter, body)
      _parts -> {:error, :invalid_frontmatter}
    end
  end

  defp split(_content) do
    {:error, :invalid_frontmatter}
  end

  defp fields(frontmatter, body) do
    frontmatter
    |> String.split("\n", trim: true)
    |> Enum.reduce_while({:ok, %{}}, &field/2)
    |> field_result(body)
  end

  defp field(line, {:ok, fields}) do
    case String.split(line, ":", parts: 2) do
      [key, value] -> put_field(fields, String.trim(key), String.trim(value))
      _parts -> {:halt, {:error, :invalid_frontmatter}}
    end
  end

  defp put_field(_fields, "", _value) do
    {:halt, {:error, :invalid_frontmatter}}
  end

  defp put_field(fields, key, value) do
    case {Map.has_key?(fields, key), scalar(value)} do
      {false, {:ok, decoded}} -> {:cont, {:ok, Map.put(fields, key, decoded)}}
      _invalid -> {:halt, {:error, :invalid_frontmatter}}
    end
  end

  defp scalar(<<quote, rest::binary>>) when quote in [?", ?'] do
    rest
    |> String.ends_with?(<<quote>>)
    |> quoted_scalar(rest)
  end

  defp scalar(value) do
    {:ok, value}
  end

  defp quoted_scalar(true, rest) when byte_size(rest) > 0 do
    {:ok, binary_part(rest, 0, byte_size(rest) - 1)}
  end

  defp quoted_scalar(false, _rest) do
    :error
  end

  defp field_result({:ok, fields}, body) do
    {:ok, fields, body}
  end

  defp field_result({:error, :invalid_frontmatter} = error, _body) do
    error
  end
end
