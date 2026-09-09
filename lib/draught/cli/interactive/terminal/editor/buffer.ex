defmodule Draught.CLI.Interactive.Terminal.Editor.Buffer do
  @moduledoc """
  Holds bounded prompt text as a grapheme-aware cursor zipper.

  Text before the cursor is stored in reverse order, making the common insert,
  delete, and horizontal movement transitions constant-time. Vertical movement
  is derived from logical newline boundaries and remains a pure transition.
  """

  @enforce_keys [:after, :before, :bytes, :maximum_bytes]
  defstruct [:after, :before, :bytes, :maximum_bytes]

  @type t :: %__MODULE__{
          after: [String.t()],
          before: [String.t()],
          bytes: non_neg_integer(),
          maximum_bytes: pos_integer()
        }

  @doc "Builds an empty buffer with a fixed UTF-8 byte limit."
  @spec new(pos_integer()) :: t()
  def new(maximum_bytes) when is_integer(maximum_bytes) and maximum_bytes > 0 do
    %__MODULE__{after: [], before: [], bytes: 0, maximum_bytes: maximum_bytes}
  end

  @doc "Returns the complete prompt text."
  @spec text(t()) :: String.t()
  def text(%__MODULE__{} = buffer) do
    buffer.before
    |> Enum.reverse(buffer.after)
    |> IO.iodata_to_binary()
  end

  @doc "Returns text strictly before the cursor."
  @spec prefix(t()) :: String.t()
  def prefix(%__MODULE__{} = buffer) do
    buffer.before
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end

  @doc "Returns the cursor's grapheme offset."
  @spec cursor(t()) :: non_neg_integer()
  def cursor(%__MODULE__{} = buffer) do
    length(buffer.before)
  end

  @doc "Reports whether the buffer contains no text."
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{} = buffer) do
    buffer.before == [] and buffer.after == []
  end

  @doc "Inserts complete valid UTF-8 text at the cursor or rejects it atomically."
  @spec insert(t(), String.t()) :: {:ok, t()} | {:error, :invalid_text | :too_large}
  def insert(%__MODULE__{} = buffer, value) when is_binary(value) do
    valid = String.valid?(value) and buffer.bytes + byte_size(value) <= buffer.maximum_bytes
    insert_result(valid, buffer, value)
  end

  def insert(%__MODULE__{}, _value) do
    {:error, :invalid_text}
  end

  @doc "Moves one grapheme left when possible."
  @spec left(t()) :: t()
  def left(%__MODULE__{before: [grapheme | rest]} = buffer) do
    %{buffer | after: [grapheme | buffer.after], before: rest}
  end

  def left(%__MODULE__{} = buffer) do
    buffer
  end

  @doc "Moves one grapheme right when possible."
  @spec right(t()) :: t()
  def right(%__MODULE__{after: [grapheme | rest]} = buffer) do
    %{buffer | after: rest, before: [grapheme | buffer.before]}
  end

  def right(%__MODULE__{} = buffer) do
    buffer
  end

  @doc "Moves to the start of the current logical line."
  @spec home(t()) :: t()
  def home(%__MODULE__{} = buffer) do
    move_to_start(buffer)
  end

  @doc "Moves to the end of the current logical line."
  @spec end_of_line(t()) :: t()
  def end_of_line(%__MODULE__{} = buffer) do
    move_to_end(buffer)
  end

  @doc "Moves to the closest column on the previous logical line."
  @spec up(t()) :: t()
  def up(%__MODULE__{} = buffer) do
    move_vertical(buffer, -1)
  end

  @doc "Moves to the closest column on the next logical line."
  @spec down(t()) :: t()
  def down(%__MODULE__{} = buffer) do
    move_vertical(buffer, 1)
  end

  @doc "Deletes the grapheme before the cursor."
  @spec backspace(t()) :: t()
  def backspace(%__MODULE__{before: [grapheme | rest]} = buffer) do
    %{buffer | before: rest, bytes: buffer.bytes - byte_size(grapheme)}
  end

  def backspace(%__MODULE__{} = buffer) do
    buffer
  end

  @doc "Deletes the grapheme at the cursor."
  @spec delete(t()) :: t()
  def delete(%__MODULE__{after: [grapheme | rest]} = buffer) do
    %{buffer | after: rest, bytes: buffer.bytes - byte_size(grapheme)}
  end

  def delete(%__MODULE__{} = buffer) do
    buffer
  end

  defp insert_result(true, buffer, value) do
    graphemes = String.graphemes(value)
    inserted = Enum.reverse(graphemes, buffer.before)

    {:ok,
     %{
       buffer
       | before: inserted,
         bytes: buffer.bytes + byte_size(value)
     }}
  end

  defp insert_result(false, buffer, value) do
    invalid_result(String.valid?(value), buffer, value)
  end

  defp invalid_result(false, _buffer, _value) do
    {:error, :invalid_text}
  end

  defp invalid_result(true, _buffer, _value) do
    {:error, :too_large}
  end

  defp move_to_start(%__MODULE__{before: ["\n" | _rest]} = buffer) do
    buffer
  end

  defp move_to_start(%__MODULE__{before: []} = buffer) do
    buffer
  end

  defp move_to_start(buffer) do
    buffer
    |> left()
    |> move_to_start()
  end

  defp move_to_end(%__MODULE__{after: ["\n" | _rest]} = buffer) do
    buffer
  end

  defp move_to_end(%__MODULE__{after: []} = buffer) do
    buffer
  end

  defp move_to_end(buffer) do
    buffer
    |> right()
    |> move_to_end()
  end

  defp move_vertical(buffer, offset) do
    lines =
      buffer
      |> text()
      |> String.split("\n")
      |> Enum.map(&String.graphemes/1)

    {row, column} = line_and_column(lines, cursor(buffer))
    target = row + offset
    move_to_line(buffer, lines, target, column)
  end

  defp line_and_column(lines, cursor) do
    Enum.reduce_while(lines, {0, cursor}, fn line, {row, remaining} ->
      line_length = length(line)
      within_line? = remaining <= line_length
      line_position(within_line?, row, remaining, line_length)
    end)
  end

  defp line_position(true, row, remaining, _line_length) do
    {:halt, {row, remaining}}
  end

  defp line_position(false, row, remaining, line_length) do
    {:cont, {row + 1, remaining - line_length - 1}}
  end

  defp move_to_line(buffer, lines, target, column) when target >= 0 do
    result = Enum.fetch(lines, target)
    move_to_fetched_line(result, buffer, lines, target, column)
  end

  defp move_to_line(buffer, _lines, _target, _column) do
    buffer
  end

  defp move_to_fetched_line({:ok, line}, buffer, lines, target, column) do
    target_column = min(column, length(line))

    target_cursor =
      lines
      |> Enum.take(target)
      |> Enum.reduce(0, fn line, count -> count + length(line) + 1 end)
      |> Kernel.+(target_column)

    move_to_cursor(buffer, target_cursor)
  end

  defp move_to_fetched_line(:error, buffer, _lines, _target, _column) do
    buffer
  end

  defp move_to_cursor(buffer, target) do
    graphemes = Enum.reverse(buffer.before, buffer.after)
    {before, after_cursor} = Enum.split(graphemes, target)
    %{buffer | after: after_cursor, before: Enum.reverse(before)}
  end
end
