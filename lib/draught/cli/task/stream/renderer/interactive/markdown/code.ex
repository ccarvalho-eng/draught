defmodule Draught.CLI.Task.Stream.Renderer.Interactive.Markdown.Code do
  @moduledoc """
  Converts bounded Makeup tokens into terminal-safe semantic styling.

  Lexer failures degrade to the original code so presentation cannot terminate
  an otherwise valid agent stream.
  """

  alias Draught.CLI.Task.Stream.Renderer.Interactive.Markdown.State
  alias Draught.CLI.UI.Theme
  alias Makeup.Lexers.ElixirLexer
  alias Makeup.Lexers.ErlangLexer

  @doc "Highlights one bounded code line for a supported language."
  @spec highlight(String.t(), State.language()) :: iodata()
  def highlight(content, :plain) do
    content
  end

  def highlight(content, language) when language in [:elixir, :erlang] do
    safely_highlight(fn -> highlight_tokens(content, language) end, content)
  end

  defp tokenize(content, :elixir) do
    ElixirLexer.lex(content)
  end

  defp tokenize(content, :erlang) do
    ErlangLexer.lex(content)
  end

  defp safely_highlight(highlighter, fallback) do
    highlighter.()
  catch
    kind, _reason when kind in [:error, :exit, :throw] -> fallback
  end

  defp highlight_tokens(content, language) do
    content
    |> tokenize(language)
    |> render()
  end

  defp render(tokens) do
    tokens
    |> Enum.map(&classify/1)
    |> Enum.chunk_by(&elem(&1, 0))
    |> Enum.map(&render_group/1)
  end

  defp classify({type, _metadata, value}) do
    {role(type), value}
  end

  defp render_group([{nil, _value} | _rest] = group) do
    Enum.map(group, &elem(&1, 1))
  end

  defp render_group([{role, _value} | _rest] = group) do
    content = Enum.map(group, &elem(&1, 1))
    Theme.chardata(content, role, true)
  end

  defp role(type) do
    type
    |> Atom.to_string()
    |> token_role()
  end

  defp token_role("comment" <> _rest) do
    :code_comment
  end

  defp token_role("keyword" <> _rest) do
    :code_keyword
  end

  defp token_role("string" <> _rest) do
    :code_string
  end

  defp token_role("number" <> _rest) do
    :code_number
  end

  defp token_role(name) when name in ["name_class", "name_function", "name_namespace"] do
    :code_name
  end

  defp token_role(_type) do
    nil
  end
end
