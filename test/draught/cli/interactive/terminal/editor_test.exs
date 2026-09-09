defmodule Draught.CLI.Interactive.Terminal.EditorTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Interactive.Completion.Context
  alias Draught.CLI.Interactive.Terminal.Editor

  defmodule Driver do
    @spec enter_raw(pid()) :: :ok | {:error, :unsupported}
    def enter_raw(agent) do
      update(agent, :entered)
      Agent.get(agent, &Map.get(&1, :entry, :ok))
    end

    @spec restore(pid()) :: :ok
    def restore(agent) do
      update(agent, :restored)
      :ok
    end

    @spec read(pid()) :: {:ok, String.t()} | :eof | {:error, :io}
    def read(agent) do
      Agent.get_and_update(agent, fn state ->
        case state.input do
          [next | rest] -> {{:ok, next}, %{state | input: rest}}
          [] -> {:eof, state}
        end
      end)
    end

    @spec write(iodata(), pid()) :: :ok
    def write(content, agent) do
      Agent.update(agent, &Map.update!(&1, :output, fn output -> [content | output] end))
      :ok
    end

    @spec columns(pid()) :: pos_integer()
    def columns(_agent) do
      80
    end

    defp update(agent, event) do
      Agent.update(agent, &Map.update!(&1, :events, fn events -> [event | events] end))
    end
  end

  test "submits edited multiline input and restores terminal state" do
    input = ["h", "i", "\n", "t", "h", "e", "r", "e", "\e", "[", "D", "!", "\r"]
    driver = driver(input)

    assert Editor.read(context(), {Driver, driver}) == {:ok, "hi\nther!e\n"}
    state = Agent.get(driver, & &1)
    assert Enum.reverse(state.events) == [:entered, :restored]

    output =
      state.output
      |> Enum.reverse()
      |> IO.iodata_to_binary()

    assert output =~ "hi\r\n│   ther!e"
  end

  test "normalizes and sanitizes bracketed paste without partial oversized insertion" do
    paste = ["\e", "[", "2", "0", "0", "~", "a\r\nb\e[2J", "\e", "[", "2", "0", "1", "~", "\r"]
    driver = driver(paste)

    assert Editor.read(context(), {Driver, driver}) == {:ok, "a\nb\n"}
  end

  test "rejects an oversized bracketed paste without retaining a prefix" do
    pasted = String.duplicate("x", 65_536)
    start_marker = ["\e", "[", "2", "0", "0", "~"]
    end_marker = ["\e", "[", "2", "0", "1", "~"]
    input = Enum.concat([start_marker, [pasted], end_marker, ["\r"]])
    driver = driver(input)

    assert Editor.read(context(), {Driver, driver}) == {:ok, "\n"}

    output =
      driver
      |> Agent.get(& &1.output)
      |> Enum.reverse()
      |> IO.iodata_to_binary()

    assert output =~ "\a"
    refute output =~ String.duplicate("x", 32)
  end

  test "reserves the record delimiter within the parser byte limit" do
    pasted = String.duplicate("x", 65_535)
    start_marker = ["\e", "[", "2", "0", "0", "~"]
    end_marker = ["\e", "[", "2", "0", "1", "~"]
    input = Enum.concat([start_marker, [pasted], end_marker, ["\r"]])
    driver = driver(input)

    assert {:ok, submitted} = Editor.read(context(), {Driver, driver})
    assert byte_size(submitted) == 65_536
  end

  test "completes a slash command before submission" do
    driver = driver(["/", "h", "e", "\t", "\r"])

    assert Editor.read(context(), {Driver, driver}) == {:ok, "/help\n"}
  end

  test "interrupts the current prompt and restores terminal state" do
    driver = driver(["d", "r", "a", "f", "t", "\x03"])

    assert Editor.read(context(), {Driver, driver}) == :interrupted

    state = Agent.get(driver, & &1)
    assert Enum.reverse(state.events) == [:entered, :restored]

    output =
      state.output
      |> Enum.reverse()
      |> IO.iodata_to_binary()

    assert output =~ "^C"
    assert output =~ "\e[?2004h"
    assert output =~ "\e[?2004l"
  end

  test "reports unsupported raw mode so the adapter can use cooked input" do
    driver = driver([], entry: {:error, :unsupported})
    assert Editor.read(context(), {Driver, driver}) == {:error, :unsupported}
    assert Agent.get(driver, & &1.events) == [:entered]
  end

  defp context do
    %Context{commands: ["/help"], models: [], skills: []}
  end

  defp driver(input, options \\ []) do
    initial = %{entry: Keyword.get(options, :entry, :ok), events: [], input: input, output: []}
    start_supervised!({Agent, fn -> initial end})
  end
end
