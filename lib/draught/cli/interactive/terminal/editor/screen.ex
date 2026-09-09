defmodule Draught.CLI.Interactive.Terminal.Editor.Screen do
  @moduledoc """
  Projects editor state onto a bounded terminal region.

  Redraws are relative to the cursor left by the previous projection. The
  caller owns the already-rendered input prefix; this module clears and
  replaces only the editable region beneath it.
  """

  alias Draught.CLI.Interactive.Terminal.Editor.Buffer
  alias Elixir.Owl.Data

  @enforce_keys [:continuation, :cursor_row, :prompt_columns, :width]
  defstruct [:continuation, :cursor_row, :prompt_columns, :width]

  @type position :: {non_neg_integer(), non_neg_integer()}
  @type projection :: %{cursor: position(), end_position: position()}
  @type t :: %__MODULE__{
          continuation: String.t(),
          cursor_row: non_neg_integer(),
          prompt_columns: non_neg_integer(),
          width: pos_integer()
        }

  @doc "Builds an empty screen projection for the current input prefix."
  @spec new(pos_integer(), non_neg_integer(), String.t()) :: t()
  def new(width, prompt_columns, continuation)
      when is_integer(width) and width > 0 and is_integer(prompt_columns) and
             prompt_columns >= 0 and is_binary(continuation) do
    %__MODULE__{
      continuation: continuation,
      cursor_row: 0,
      prompt_columns: min(prompt_columns, width - 1),
      width: width
    }
  end

  @doc "Returns cursor and end positions for the current terminal width."
  @spec layout(Buffer.t(), pos_integer(), non_neg_integer()) :: projection()
  def layout(%Buffer{} = buffer, width, prompt_columns)
      when is_integer(width) and width > 0 and is_integer(prompt_columns) and
             prompt_columns >= 0 do
    graphemes =
      buffer
      |> Buffer.text()
      |> String.graphemes()

    cursor = position(Enum.take(graphemes, Buffer.cursor(buffer)), width, prompt_columns)
    end_position = position(graphemes, width, prompt_columns)
    %{cursor: cursor, end_position: end_position}
  end

  @doc "Clears and redraws the editable region, leaving the cursor at its logical offset."
  @spec redraw(t(), Buffer.t()) :: {iodata(), t()}
  def redraw(%__MODULE__{} = screen, %Buffer{} = buffer) do
    projection = layout(buffer, screen.width, screen.prompt_columns)

    text =
      buffer
      |> Buffer.text()
      |> visible_text(screen.continuation)

    output = [
      rewind(screen.cursor_row, screen.prompt_columns),
      text,
      position_from_end(projection.end_position, projection.cursor)
    ]

    {cursor_row, _column} = projection.cursor
    {output, %{screen | cursor_row: cursor_row}}
  end

  @doc "Draws the final value and advances to the line below the editable region."
  @spec finish(t(), Buffer.t()) :: iodata()
  def finish(%__MODULE__{} = screen, %Buffer{} = buffer) do
    projection = layout(buffer, screen.width, screen.prompt_columns)
    {redraw, _screen} = redraw(screen, buffer)

    [redraw, position_from_cursor(projection.cursor, projection.end_position), "\r\n"]
  end

  defp position(graphemes, width, prompt_columns) do
    Enum.reduce(graphemes, {0, min(prompt_columns, width - 1)}, fn grapheme, position ->
      advance(grapheme, position, width, prompt_columns)
    end)
  end

  defp advance("\n", {row, _column}, _width, prompt_columns) do
    {row + 1, prompt_columns}
  end

  defp advance("\t", {row, column}, width, _prompt_columns) do
    columns = 8 - rem(column, 8)
    total = column + columns
    {row + div(total, width), rem(total, width)}
  end

  defp advance(grapheme, {row, column}, width, _prompt_columns) do
    columns = max(Data.length(grapheme), 0)
    total = column + columns
    {row + div(total, width), rem(total, width)}
  end

  defp visible_text(text, continuation) do
    String.replace(text, "\n", "\r\n" <> continuation)
  end

  defp rewind(cursor_row, prompt_columns) do
    [vertical(:up, cursor_row), "\r", horizontal(prompt_columns), "\e[J"]
  end

  defp position_from_end({end_row, _end_column}, {cursor_row, cursor_column}) do
    [vertical(:up, end_row - cursor_row), "\r", horizontal(cursor_column)]
  end

  defp position_from_cursor({cursor_row, _cursor_column}, {end_row, end_column}) do
    [vertical(:down, end_row - cursor_row), "\r", horizontal(end_column)]
  end

  defp vertical(_direction, 0) do
    ""
  end

  defp vertical(:up, rows) do
    IO.ANSI.cursor_up(rows)
  end

  defp vertical(:down, rows) do
    IO.ANSI.cursor_down(rows)
  end

  defp horizontal(0) do
    ""
  end

  defp horizontal(columns) do
    IO.ANSI.cursor_right(columns)
  end
end
