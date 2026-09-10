defmodule Draught.CLI.UI.SkillDescription do
  @moduledoc """
  Sanitizes skill metadata and produces complete summaries for compact catalogs.
  """

  alias Draught.CLI.UI.SafeLine

  @fallback "See skill instructions"
  @maximum_bytes 44
  @summary_boundary ~r/(?:[,;:]|\s+(?:across|as|before|by|for|from|only|so|using|when|with)\s+)/u

  @doc "Returns display-safe skill metadata with a generous defensive bound."
  @spec safe(String.t()) :: String.t()
  def safe(value) do
    SafeLine.text(value, 2_048)
  end

  @doc "Returns a short skill summary without partial words or ellipses."
  @spec summary(String.t()) :: String.t()
  def summary(description) do
    description
    |> safe()
    |> first_clause()
    |> fit_words()
  end

  defp first_clause(description) do
    description
    |> then(&Regex.split(@summary_boundary, &1, parts: 2))
    |> List.first()
    |> String.trim()
    |> String.trim_trailing(".")
  end

  defp fit_words(description) when byte_size(description) <= @maximum_bytes do
    fallback_if_empty(description)
  end

  defp fit_words(description) do
    description
    |> String.split()
    |> Enum.reduce_while("", &append_word/2)
    |> fallback_if_empty()
  end

  defp append_word(word, "") when byte_size(word) <= @maximum_bytes do
    {:cont, word}
  end

  defp append_word(word, summary) do
    candidate = summary <> " " <> word
    append_candidate(candidate, summary)
  end

  defp append_candidate(candidate, _summary) when byte_size(candidate) <= @maximum_bytes do
    {:cont, candidate}
  end

  defp append_candidate(_candidate, summary) do
    {:halt, summary}
  end

  defp fallback_if_empty("") do
    @fallback
  end

  defp fallback_if_empty(summary) do
    summary
  end
end
