defmodule Draught.CLI.Interactive.Terminal.Editor.KeyTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Interactive.Terminal.Editor.Key

  defmodule Driver do
    @spec read(pid()) :: {:ok, String.t()} | :eof
    def read(agent) do
      Agent.get_and_update(agent, fn
        [next | rest] -> {{:ok, next}, rest}
        [] -> {:eof, []}
      end)
    end
  end

  test "decodes navigation, editing, and newline keys" do
    assert read(["\e", "[", "D"]) == :left
    assert read(["\e", "[", "3", "~"]) == :delete
    assert read(["\e", "\r"]) == :newline
    assert read(["\n"]) == :newline
    assert read(["\r"]) == :submit
    assert read(["λ"]) == {:insert, "λ"}
  end

  test "captures a bracketed multiline paste as one bounded event" do
    input = ["\e", "[", "2", "0", "0", "~", "one", "\r", "\n", "two"]
    ending = ["\e", "[", "2", "0", "1", "~"]

    assert read(input ++ ending, 32) == {:paste, "one\r\ntwo"}
    assert read(input ++ ending, 4) == {:error, :too_large}
  end

  defp read(input, maximum_bytes \\ 65_536) do
    child = Supervisor.child_spec({Agent, fn -> input end}, id: make_ref())
    agent = start_supervised!(child)
    Key.read(Driver, agent, maximum_bytes)
  end
end
