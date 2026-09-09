defmodule Draught.CLI.Interactive.Terminal.Editor.Key do
  @moduledoc """
  Decodes bounded raw terminal input into semantic editor events.

  Escape sequences are read only to a fixed depth. Bracketed paste is consumed
  until its terminal marker while retaining at most the configured input size.
  """

  @paste_end "\e[201~"
  @maximum_escape_characters 8

  @type event ::
          :backspace
          | :delete
          | :down
          | :end_of_line
          | :eof
          | :home
          | :ignore
          | :interrupt
          | :left
          | :newline
          | :right
          | :submit
          | :tab
          | :up
          | {:error, :io | :too_large}
          | {:insert, String.t()}
          | {:paste, String.t()}

  @doc "Reads and decodes one editor event from an injected terminal driver."
  @spec read(module(), term(), pos_integer()) :: event()
  def read(driver, configuration, maximum_bytes)
      when is_atom(driver) and is_integer(maximum_bytes) and maximum_bytes > 0 do
    case driver.read(configuration) do
      {:ok, "\e"} -> escape(driver, configuration, maximum_bytes)
      {:ok, value} when is_binary(value) -> key(value)
      :eof -> :eof
      {:error, :io} -> {:error, :io}
      _invalid -> {:error, :io}
    end
  end

  defp key("\r") do
    :submit
  end

  defp key("\r\n") do
    :submit
  end

  defp key("\n") do
    :newline
  end

  defp key("\t") do
    :tab
  end

  defp key("\x01") do
    :home
  end

  defp key("\x03") do
    :interrupt
  end

  defp key("\x04") do
    :eof
  end

  defp key("\x05") do
    :end_of_line
  end

  defp key("\x08") do
    :backspace
  end

  defp key("\x7f") do
    :backspace
  end

  defp key(value) when is_binary(value) do
    insert_result(String.valid?(value), value)
  end

  defp insert_result(true, value) do
    {:insert, value}
  end

  defp insert_result(false, _value) do
    {:error, :io}
  end

  defp escape(driver, configuration, maximum_bytes) do
    case driver.read(configuration) do
      {:ok, value} when value in ["\r", "\n"] -> :newline
      {:ok, "["} -> escape_sequence(driver, configuration, "[", maximum_bytes, 1)
      {:ok, "O"} -> escape_sequence(driver, configuration, "O", maximum_bytes, 1)
      {:ok, _value} -> :ignore
      :eof -> :ignore
      {:error, :io} -> {:error, :io}
      _invalid -> {:error, :io}
    end
  end

  defp escape_sequence(driver, configuration, sequence, maximum_bytes, count)
       when count < @maximum_escape_characters do
    case driver.read(configuration) do
      {:ok, value} when is_binary(value) ->
        combined = sequence <> value

        escape_result(
          complete_escape?(combined),
          driver,
          configuration,
          combined,
          maximum_bytes,
          count
        )

      :eof ->
        :ignore

      {:error, :io} ->
        {:error, :io}

      _invalid ->
        {:error, :io}
    end
  end

  defp escape_sequence(_driver, _configuration, _sequence, _maximum_bytes, _count) do
    :ignore
  end

  defp escape_result(true, driver, configuration, "[200~", maximum_bytes, _count) do
    paste(driver, configuration, maximum_bytes)
  end

  defp escape_result(true, _driver, _configuration, sequence, _maximum_bytes, _count) do
    escape_key(sequence)
  end

  defp escape_result(false, driver, configuration, sequence, maximum_bytes, count) do
    escape_sequence(driver, configuration, sequence, maximum_bytes, count + 1)
  end

  defp complete_escape?(sequence) do
    String.match?(sequence, ~r/[A-Za-z~]\z/u)
  end

  defp escape_key(sequence) when sequence in ["[A", "OA"] do
    :up
  end

  defp escape_key(sequence) when sequence in ["[B", "OB"] do
    :down
  end

  defp escape_key(sequence) when sequence in ["[C", "OC"] do
    :right
  end

  defp escape_key(sequence) when sequence in ["[D", "OD"] do
    :left
  end

  defp escape_key(sequence) when sequence in ["[H", "OH", "[1~"] do
    :home
  end

  defp escape_key(sequence) when sequence in ["[F", "OF", "[4~"] do
    :end_of_line
  end

  defp escape_key("[3~") do
    :delete
  end

  defp escape_key(_sequence) do
    :ignore
  end

  defp paste(driver, configuration, maximum_bytes) do
    state = %{bytes: 0, chunks: [], maximum_bytes: maximum_bytes, overflow?: false, pending: ""}
    paste_loop(driver, configuration, state)
  end

  defp paste_loop(driver, configuration, state) do
    case driver.read(configuration) do
      {:ok, value} when is_binary(value) ->
        value
        |> String.graphemes()
        |> Enum.reduce_while({:continue, state}, &paste_character/2)
        |> paste_result(driver, configuration)

      :eof ->
        {:error, :io}

      {:error, :io} ->
        {:error, :io}

      _invalid ->
        {:error, :io}
    end
  end

  defp paste_character(character, {:continue, state}) do
    state.pending
    |> Kernel.<>(character)
    |> consume_pending(%{state | pending: ""})
  end

  defp consume_pending(@paste_end, state) do
    {:halt, {:done, state}}
  end

  defp consume_pending(candidate, state) do
    marker_prefix? = String.starts_with?(@paste_end, candidate)
    pending_result(marker_prefix?, candidate, state)
  end

  defp pending_result(true, candidate, state) do
    {:cont, {:continue, %{state | pending: candidate}}}
  end

  defp pending_result(false, candidate, state) do
    flush_candidate(candidate, state)
  end

  defp flush_candidate(candidate, state) do
    [first | rest] = String.graphemes(candidate)
    state = retain(first, state)

    case rest do
      [] -> {:cont, {:continue, state}}
      remaining -> consume_pending(Enum.join(remaining), state)
    end
  end

  defp retain(character, state) do
    bytes = state.bytes + byte_size(character)
    fits? = bytes <= state.maximum_bytes

    %{
      state
      | bytes: bytes,
        chunks: retain_chunk(fits?, character, state.chunks),
        overflow?: state.overflow? or not fits?
    }
  end

  defp retain_chunk(true, character, chunks) do
    [character | chunks]
  end

  defp retain_chunk(false, _character, chunks) do
    chunks
  end

  defp paste_result({:continue, state}, driver, configuration) do
    paste_loop(driver, configuration, state)
  end

  defp paste_result({:done, %{overflow?: true}}, _driver, _configuration) do
    {:error, :too_large}
  end

  defp paste_result({:done, state}, _driver, _configuration) do
    content =
      state.chunks
      |> Enum.reverse()
      |> IO.iodata_to_binary()

    {:paste, content}
  end
end
