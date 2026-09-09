defmodule Draught.CLI.Interactive.Terminal.Editor do
  @moduledoc """
  Runs one bounded raw-mode prompt edit with cooked-input fallback signaling.

  The editor is active only while the interactive session is idle. It restores
  cooked mode before a task starts, leaving approvals on the existing
  supervised line-input boundary.
  """

  alias Draught.CLI.Interactive.Completion
  alias Draught.CLI.Interactive.Completion.Context
  alias Draught.CLI.Interactive.Input
  alias Draught.CLI.Interactive.Terminal.Editor.Buffer
  alias Draught.CLI.Interactive.Terminal.Editor.Key
  alias Draught.CLI.Interactive.Terminal.Editor.Screen
  alias Draught.CLI.Output.Sanitizer

  @bracketed_paste_on "\e[?2004h"
  @bracketed_paste_off "\e[?2004l"
  @bell "\a"

  @type driver :: {module(), term()}
  @type result ::
          {:ok, String.t()}
          | :eof
          | :interrupted
          | {:error, :io | :unsupported}

  @doc "Reads one editable prompt through the supplied raw terminal driver."
  @spec read(Context.t(), driver()) :: result()
  def read(%Context{} = context, driver) do
    {module, configuration} = driver

    case module.enter_raw(configuration) do
      :ok -> run(context, module, configuration)
      {:error, :unsupported} -> {:error, :unsupported}
    end
  end

  defp run(context, driver, configuration) do
    _write_result = driver.write(@bracketed_paste_on, configuration)
    width = driver.columns(configuration)
    screen = Screen.new(width, prompt_columns(width), continuation(width))
    buffer = Buffer.new(maximum_buffer_bytes())

    try do
      loop(buffer, screen, context, driver, configuration)
    after
      _write_result = driver.write(@bracketed_paste_off, configuration)
      :ok = driver.restore(configuration)
    end
  end

  defp loop(buffer, screen, context, driver, configuration) do
    driver
    |> Key.read(configuration, maximum_buffer_bytes())
    |> transition(buffer, screen, context, driver, configuration)
  end

  defp transition(:submit, buffer, screen, _context, driver, configuration) do
    output = Screen.finish(screen, buffer)

    with :ok <- driver.write(output, configuration) do
      {:ok, Buffer.text(buffer) <> "\n"}
    end
  end

  defp transition(:interrupt, _buffer, screen, _context, driver, configuration) do
    output = clear(screen, "^C")

    with :ok <- driver.write(output, configuration) do
      :interrupted
    end
  end

  defp transition(:eof, buffer, screen, context, driver, configuration) do
    eof(Buffer.empty?(buffer), buffer, screen, context, driver, configuration)
  end

  defp transition({:error, :io}, _buffer, _screen, _context, _driver, _configuration) do
    {:error, :io}
  end

  defp transition({:error, :too_large}, buffer, screen, context, driver, configuration) do
    with :ok <- driver.write(@bell, configuration) do
      loop(buffer, screen, context, driver, configuration)
    end
  end

  defp transition(:ignore, buffer, screen, context, driver, configuration) do
    loop(buffer, screen, context, driver, configuration)
  end

  defp transition(:tab, buffer, screen, context, driver, configuration) do
    context
    |> completion(buffer)
    |> update(buffer, screen, context, driver, configuration)
  end

  defp transition({:insert, value}, buffer, screen, context, driver, configuration) do
    value
    |> Sanitizer.text()
    |> insert(buffer)
    |> update(buffer, screen, context, driver, configuration)
  end

  defp transition({:paste, value}, buffer, screen, context, driver, configuration) do
    value
    |> normalize_paste()
    |> insert(buffer)
    |> update(buffer, screen, context, driver, configuration)
  end

  defp transition(:newline, buffer, screen, context, driver, configuration) do
    update(Buffer.insert(buffer, "\n"), buffer, screen, context, driver, configuration)
  end

  defp transition(event, buffer, screen, context, driver, configuration) do
    event
    |> edit(buffer)
    |> then(&update({:ok, &1}, buffer, screen, context, driver, configuration))
  end

  defp edit(:left, buffer) do
    Buffer.left(buffer)
  end

  defp edit(:right, buffer) do
    Buffer.right(buffer)
  end

  defp edit(:up, buffer) do
    Buffer.up(buffer)
  end

  defp edit(:down, buffer) do
    Buffer.down(buffer)
  end

  defp edit(:home, buffer) do
    Buffer.home(buffer)
  end

  defp edit(:end_of_line, buffer) do
    Buffer.end_of_line(buffer)
  end

  defp edit(:backspace, buffer) do
    Buffer.backspace(buffer)
  end

  defp edit(:delete, buffer) do
    Buffer.delete(buffer)
  end

  defp eof(true, _buffer, screen, _context, driver, configuration) do
    output = clear(screen, "")

    with :ok <- driver.write(output, configuration) do
      :eof
    end
  end

  defp eof(false, buffer, screen, context, driver, configuration) do
    updated = Buffer.delete(buffer)
    update({:ok, updated}, buffer, screen, context, driver, configuration)
  end

  defp completion(context, buffer) do
    prefix = Buffer.prefix(buffer)
    characters = String.to_charlist(prefix)
    reversed = Enum.reverse(characters)

    case Completion.expand(reversed, context) do
      {:yes, suffix, _matches} -> completion_result(suffix, buffer)
      {:no, _suffix, _matches} -> {:ok, buffer}
    end
  rescue
    ArgumentError -> {:ok, buffer}
  end

  defp insert("", buffer) do
    {:ok, buffer}
  end

  defp insert(value, buffer) do
    Buffer.insert(buffer, value)
  end

  defp completion_result(suffix, buffer) do
    value = :unicode.characters_to_binary(suffix)
    insert(value, buffer)
  end

  defp update({:ok, updated}, _previous, screen, context, driver, configuration) do
    {output, next_screen} = Screen.redraw(screen, updated)

    with :ok <- driver.write(output, configuration) do
      loop(updated, next_screen, context, driver, configuration)
    end
  end

  defp update({:error, _reason}, previous, screen, context, driver, configuration) do
    with :ok <- driver.write(@bell, configuration) do
      loop(previous, screen, context, driver, configuration)
    end
  end

  defp normalize_paste(value) do
    value
    |> String.replace("\r\n", "\n")
    |> String.replace("\r", "\n")
    |> Sanitizer.text()
  end

  defp prompt_columns(width) when width >= 8 do
    4
  end

  defp prompt_columns(1) do
    1
  end

  defp prompt_columns(_width) do
    2
  end

  defp continuation(width) when width >= 8 do
    "│   "
  end

  defp continuation(_width) do
    ""
  end

  defp clear(screen, suffix) do
    empty = Buffer.new(maximum_buffer_bytes())
    {redraw, _screen} = Screen.redraw(screen, empty)
    [redraw, suffix]
  end

  defp maximum_buffer_bytes do
    Input.maximum_bytes() - byte_size("\n")
  end
end
