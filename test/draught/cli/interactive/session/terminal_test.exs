defmodule Draught.CLI.Interactive.Session.TerminalTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Dependencies
  alias Draught.CLI.Interactive.Session.Terminal
  alias Draught.CLI.Interactive.State
  alias Draught.CLI.UI

  defmodule SystemAdapter do
    @behaviour Draught.CLI.System.Adapter

    @impl Draught.CLI.System.Adapter
    def cwd(_configuration) do
      {:ok, "/workspace"}
    end

    @impl Draught.CLI.System.Adapter
    def environment(_configuration) do
      %{}
    end

    @impl Draught.CLI.System.Adapter
    def read_file(_path, _limit, _configuration) do
      :missing
    end

    @impl Draught.CLI.System.Adapter
    def workspace(_path, _configuration) do
      :ok
    end

    @impl Draught.CLI.System.Adapter
    def tty?(_stream, _configuration) do
      true
    end

    @impl Draught.CLI.System.Adapter
    def columns(configuration) do
      configuration.columns
    end

    @impl Draught.CLI.System.Adapter
    def write(stream, content, configuration) do
      text = IO.iodata_to_binary(content)
      send(configuration.owner, {:output, stream, text})
      opening? = String.ends_with?(text, "› ")

      write_result(configuration.failure == opening?)
    end

    defp write_result(true) do
      {:error, :closed}
    end

    defp write_result(false) do
      :ok
    end
  end

  defmodule TerminalAdapter do
    @behaviour Draught.CLI.Interactive.Terminal.Adapter

    @impl Draught.CLI.Interactive.Terminal.Adapter
    def interactive?(_configuration) do
      true
    end

    @impl Draught.CLI.Interactive.Terminal.Adapter
    def read_line(configuration) do
      send(configuration.owner, :input_read)
      configuration.result
    end

    @impl Draught.CLI.Interactive.Terminal.Adapter
    def restore(_configuration) do
      :ok
    end
  end

  test "frames a line before returning its parsed command" do
    dependencies = dependencies({:ok, "/exit\n"})
    assert {:ok, {:ok, {:command, :exit, nil}}} = Terminal.read(state(), dependencies)
    assert_receive {:output, :stdout, "\n╭─ qwen3 · …\n│ › "}
    assert_receive :input_read
    assert_receive {:output, :stdout, "╰───────────\n\n"}
  end

  test "does not read any input when the opening output fails" do
    dependencies = dependencies({:ok, "unread"}, true)
    assert {:error, :write, 70} = Terminal.read(state(), dependencies)
    assert_receive {:output, :stdout, "\n╭─ qwen3 · …\n│ › "}
    refute_receive :input_read
    refute_receive {:output, _, _}
  end

  test "does not return a parsed task if the closing output fails" do
    dependencies = dependencies({:ok, "do not run this task\n"}, false)
    assert {:error, :write, 70} = Terminal.read(state(), dependencies)
    assert_receive :input_read
    assert_receive {:output, :stdout, "╰───────────\n\n"}
  end

  test "closes incomplete input lines before the next output without reflecting input" do
    input = "text without trailing newline"
    dependencies = dependencies({:ok, input})
    assert {:ok, {:ok, {:prompt, ^input}}} = Terminal.read(state(), dependencies)
    assert_receive {:output, :stdout, "\n╰───────────\n\n"}
  end

  test "preserves EOF, interruption and input errors after closing the input area" do
    for result <- [:eof, :interrupted, {:error, :io}] do
      dependencies = dependencies(result)
      assert ^result = Terminal.read(state(), dependencies)
      assert_receive {:output, :stdout, "\n╭─ qwen3 · …\n│ › "}
      assert_receive :input_read
      assert_receive {:output, :stdout, "\n╰───────────\n\n"}
    end
  end

  test "uses the bounded fallback when terminal columns are unavailable" do
    dependencies = dependencies(:eof, nil, {:error, :unavailable})

    opening =
      :open
      |> UI.input_area(state(), 50)
      |> IO.iodata_to_binary()

    closing = ["\n", UI.input_area(:close, state(), 50), "\n"]
    expected_closing = IO.iodata_to_binary(closing)

    assert :eof = Terminal.read(state(), dependencies)
    assert_receive {:output, :stdout, ^opening}
    assert_receive {:output, :stdout, ^expected_closing}
  end

  defp state do
    {:ok, state} =
      State.new(
        session_id: "session-01",
        provider: "ollama",
        model: "qwen3",
        workspace: "/workspace",
        web: false
      )

    state
  end

  defp dependencies(result, failure \\ nil, columns \\ {:ok, 12}) do
    configuration = %{owner: self(), result: result, failure: failure, columns: columns}

    {:ok, dependencies} =
      Dependencies.new(
        system: {SystemAdapter, configuration},
        terminal: {TerminalAdapter, configuration}
      )

    dependencies
  end
end
