defmodule Draught.CLI.Task.Stream.Renderer.Interactive.Markdown.Language do
  @moduledoc """
  Recognizes bounded backtick fences and their supported BEAM languages.
  """

  alias Draught.CLI.Task.Stream.Renderer.Interactive.Markdown.State

  @opening ~r/\A {0,3}(`{3,})([^`\n]*)\n\z/u
  @opening_start ~r/\A {0,3}`{3}/u
  @partial_opening ~r/\A {0,3}`{0,2}\z/u
  @closing ~r/\A {0,3}(`{3,})[ \t]*\n\z/u

  @doc "Returns whether content begins with a complete backtick fence marker."
  @spec opening_start?(String.t()) :: boolean()
  def opening_start?(content) do
    Regex.match?(@opening_start, content)
  end

  @doc "Returns whether content remains a possible partial opening marker."
  @spec partial_opening?(String.t()) :: boolean()
  def partial_opening?(content) do
    Regex.match?(@partial_opening, content)
  end

  @doc "Parses a complete opening line into a supported language and fence width."
  @spec opening(String.t()) :: {:ok, State.language(), pos_integer()} | :error
  def opening(line) do
    case Regex.run(@opening, line, capture: :all_but_first) do
      [fence, information] -> {:ok, language(information), byte_size(fence)}
      _no_match -> :error
    end
  end

  @doc "Returns whether a complete line closes the current backtick fence."
  @spec closing?(String.t(), pos_integer()) :: boolean()
  def closing?(line, opening_length) do
    case Regex.run(@closing, line, capture: :all_but_first) do
      [fence] -> byte_size(fence) >= opening_length
      _no_match -> false
    end
  end

  defp language(information) do
    information
    |> String.trim()
    |> String.downcase()
    |> String.split(~r/\s+/u, parts: 2)
    |> List.first()
    |> supported_language()
  end

  defp supported_language(language) when language in ["elixir", "ex", "exs"] do
    :elixir
  end

  defp supported_language(language) when language in ["erlang", "erl"] do
    :erlang
  end

  defp supported_language(_language) do
    :plain
  end
end
