defmodule Draught.CLI.Task.Stream.Renderer.Interactive.Markdown do
  @moduledoc """
  Streams prose immediately and highlights bounded lines inside BEAM code fences.

  Only the short possible opening marker and one code line are retained. Long
  lines or unusually large deltas degrade to unstyled streaming output, and
  `flush/1` preserves incomplete input at every terminal or tool boundary.
  """

  alias Draught.CLI.Task.Stream.Renderer.Interactive.Markdown.Code
  alias Draught.CLI.Task.Stream.Renderer.Interactive.Markdown.Language
  alias Draught.CLI.Task.Stream.Renderer.Interactive.Markdown.State
  alias Draught.CLI.UI.Theme

  @maximum_code_line_bytes 4_096
  @maximum_delta_bytes 65_536
  @maximum_delta_lines 512
  @maximum_opening_bytes 128

  @doc "Builds fresh Markdown presentation state."
  @spec new() :: State.t()
  def new do
    State.new()
  end

  @doc "Consumes one sanitized assistant text delta."
  @spec consume(State.t(), String.t()) :: {iodata(), State.t()}
  def consume(%State{} = state, content) when is_binary(content) do
    bounded = bounded_delta?(content)
    consume(state, content, bounded)
  end

  defp consume(%State{} = state, content, false) do
    {pending, reset} = flush(state)
    {[pending, content], reset}
  end

  defp consume(%State{mode: :prose} = state, content, true) do
    consume_prose(state, content)
  end

  defp consume(%State{mode: :opening} = state, content, true) do
    consume_opening(%{state | pending: state.pending <> content})
  end

  defp consume(%State{mode: :code} = state, content, true) do
    consume_code(%{state | pending: state.pending <> content})
  end

  @doc "Flushes retained input losslessly and resets presentation state."
  @spec flush(State.t()) :: {iodata(), State.t()}
  def flush(%State{mode: :prose, pending: pending}) do
    {pending, State.new()}
  end

  def flush(%State{mode: :opening, pending: pending}) do
    {pending, State.new()}
  end

  def flush(%State{mode: :code, overflow: true, pending: pending}) do
    {pending, State.new()}
  end

  def flush(%State{mode: :code, language: language, pending: pending}) do
    {Code.highlight(pending, language), State.new()}
  end

  defp consume_prose(%State{line_start: true, pending: pending} = state, content) do
    combined = pending <> content

    cond do
      Language.opening_start?(combined) ->
        consume_opening(%{state | mode: :opening, pending: combined})

      Language.partial_opening?(combined) ->
        {"", %{state | pending: combined}}

      true ->
        emit_prose(%{state | pending: ""}, combined)
    end
  end

  defp consume_prose(%State{} = state, content) do
    emit_prose(state, content)
  end

  defp emit_prose(state, content) do
    case split_line(content) do
      {:line, line, rest} ->
        {following, updated} = consume_prose(%{state | line_start: true}, rest)
        {[line, following], updated}

      :incomplete ->
        {content, %{state | line_start: false}}
    end
  end

  defp consume_opening(%State{pending: pending} = state) do
    case split_line(pending) do
      {:line, line, rest} -> complete_opening(state, line, rest)
      :incomplete -> retain_opening(state)
    end
  end

  defp complete_opening(_state, line, rest) when byte_size(line) > @maximum_opening_bytes do
    {following, updated} = consume_prose(State.new(), rest)
    {[line, following], updated}
  end

  defp complete_opening(state, line, rest) do
    open_fence(state, line, rest)
  end

  defp retain_opening(%State{pending: pending} = state)
       when byte_size(pending) > @maximum_opening_bytes do
    {pending, %{state | line_start: false, mode: :prose, pending: ""}}
  end

  defp retain_opening(state) do
    {"", state}
  end

  defp open_fence(state, line, rest) do
    case Language.opening(line) do
      {:ok, language, fence_length} ->
        code = %{
          state
          | fence_length: fence_length,
            language: language,
            mode: :code,
            pending: ""
        }

        {following, updated} = consume_code(%{code | pending: rest})
        {[Theme.chardata(line, :muted, true), following], updated}

      :error ->
        {following, updated} = consume_prose(%{State.new() | line_start: true}, rest)
        {[line, following], updated}
    end
  end

  defp consume_code(%State{pending: pending} = state) do
    case split_line(pending) do
      {:line, line, rest} -> emit_code_line(%{state | pending: ""}, line, rest)
      :incomplete -> retain_code_line(state)
    end
  end

  defp retain_code_line(%State{overflow: true, pending: pending} = state) do
    {pending, %{state | pending: ""}}
  end

  defp retain_code_line(%State{pending: pending} = state)
       when byte_size(pending) > @maximum_code_line_bytes do
    {pending, %{state | overflow: true, pending: ""}}
  end

  defp retain_code_line(state) do
    {"", state}
  end

  defp emit_code_line(%State{overflow: true} = state, line, rest) do
    {following, updated} = consume_code(%{state | overflow: false, pending: rest})
    {[line, following], updated}
  end

  defp emit_code_line(state, line, rest) do
    closing? = Language.closing?(line, state.fence_length)
    emit_code_line(state, line, rest, closing?)
  end

  defp emit_code_line(_state, line, rest, true) do
    {following, updated} = consume_prose(State.new(), rest)
    {[Theme.chardata(line, :muted, true), following], updated}
  end

  defp emit_code_line(state, line, rest, false) do
    rendered = bounded_highlight(line, state.language)
    {following, updated} = consume_code(%{state | pending: rest})
    {[rendered, following], updated}
  end

  defp bounded_highlight(line, _language)
       when byte_size(line) > @maximum_code_line_bytes do
    line
  end

  defp bounded_highlight(line, language) do
    Code.highlight(line, language)
  end

  defp bounded_delta?(content) when byte_size(content) <= @maximum_delta_bytes do
    content
    |> :binary.matches("\n")
    |> length()
    |> Kernel.<=(@maximum_delta_lines)
  end

  defp bounded_delta?(_content) do
    false
  end

  defp split_line(content) do
    case :binary.match(content, "\n") do
      {index, 1} ->
        size = index + 1

        {:line, binary_part(content, 0, size),
         binary_part(content, size, byte_size(content) - size)}

      :nomatch ->
        :incomplete
    end
  end
end
