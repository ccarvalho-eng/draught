defmodule Draught.Tool.Builtin.SearchWorkspace.Searcher do
  @moduledoc """
  Searches a stable file list under aggregate byte and match limits.

  Files are read through the bounded reader, matches preserve file and line
  order, and long lines or excess matches are truncated deterministically.
  """

  alias Draught.Tool.Builtin.ReadFile.Reader

  @maximum_file_bytes 1_048_576
  @maximum_scan_bytes 8_388_608
  @maximum_matches 200
  @maximum_line_graphemes 500

  @type reason :: :limit_exceeded | :scan_failed
  @type result :: {:ok, String.t()} | {:error, reason()}

  @doc "Searches a stable file list within fixed scan and match limits."
  @spec search(String.t(), [String.t()], String.t(), boolean()) :: result()
  def search(root, files, query, case_sensitive) do
    initial = %{bytes: 0, matches: [], match_count: 0, truncated: false}

    files
    |> Enum.reduce_while({:ok, initial}, fn file, {:ok, state} ->
      search_file(root, file, query, case_sensitive, state)
    end)
    |> format()
  end

  defp search_file(root, file, query, case_sensitive, state) do
    case Reader.read(file, @maximum_file_bytes) do
      {:ok, content} -> search_content(root, file, content, query, case_sensitive, state)
      {:error, :too_large} -> {:halt, {:error, :limit_exceeded}}
      {:error, :unreadable} -> {:cont, {:ok, state}}
    end
  end

  defp search_content(root, file, content, query, case_sensitive, state) do
    total_bytes = state.bytes + byte_size(content)

    total_bytes
    |> then(&(&1 <= @maximum_scan_bytes))
    |> scan_result(root, file, content, query, case_sensitive, state, total_bytes)
  end

  defp scan_result(true, root, file, content, query, case_sensitive, state, total_bytes) do
    content
    |> String.split("\n")
    |> collect_matches(root, file, query, case_sensitive, %{state | bytes: total_bytes})
    |> continue()
  end

  defp scan_result(false, _root, _file, _content, _query, _case_sensitive, _state, _total) do
    {:halt, {:error, :limit_exceeded}}
  end

  defp collect_matches(lines, root, file, query, case_sensitive, state) do
    lines
    |> Enum.with_index(1)
    |> Enum.reduce_while(state, fn {line, number}, current ->
      collect_match(line, number, root, file, query, case_sensitive, current)
    end)
  end

  defp collect_match(line, number, root, file, query, case_sensitive, state) do
    cond do
      state.match_count >= @maximum_matches ->
        {:halt, %{state | truncated: true}}

      matches?(line, query, case_sensitive) ->
        match = format_match(root, file, number, line)
        {:cont, %{state | matches: [match | state.matches], match_count: state.match_count + 1}}

      true ->
        {:cont, state}
    end
  end

  defp matches?(line, query, true) do
    String.contains?(line, query)
  end

  defp matches?(line, query, false) do
    line
    |> String.downcase()
    |> String.contains?(String.downcase(query))
  end

  defp format_match(root, file, number, line) do
    relative = Path.relative_to(file, root)
    content = String.slice(line, 0, @maximum_line_graphemes)
    "#{relative}:#{number}:#{content}"
  end

  defp continue(%{truncated: true} = state) do
    {:halt, {:ok, state}}
  end

  defp continue(state) do
    {:cont, {:ok, state}}
  end

  defp format({:ok, state}) do
    matches = Enum.reverse(state.matches)
    lines = append_truncation(matches, state.truncated)
    {:ok, Enum.join(lines, "\n")}
  end

  defp format({:error, _reason} = result) do
    result
  end

  defp append_truncation(matches, true) do
    matches
    |> Enum.reverse()
    |> then(&["[match limit reached]" | &1])
    |> Enum.reverse()
  end

  defp append_truncation(matches, false) do
    matches
  end
end
