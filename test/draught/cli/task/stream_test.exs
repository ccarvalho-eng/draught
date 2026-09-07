defmodule Draught.CLI.Task.StreamTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Task.Stream
  alias Draught.Conversation
  alias Draught.Error.Normalized
  alias Draught.Event.Provider.Delta
  alias Draught.Provider.Response

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
    def read_file(_path, _maximum_bytes, _configuration) do
      :missing
    end

    @impl Draught.CLI.System.Adapter
    def workspace(_path, _configuration) do
      :ok
    end

    @impl Draught.CLI.System.Adapter
    def write(_stream, _content, %{write: :closed}) do
      {:error, :closed}
    end

    def write(stream, content, configuration) do
      send(configuration.owner, {:write, stream, IO.iodata_to_binary(content)})
      :ok
    end

    @impl Draught.CLI.System.Adapter
    def tty?(stream, configuration) do
      stream == :stdout and configuration.tty
    end

    @impl Draught.CLI.System.Adapter
    def columns(%{columns: :unavailable}) do
      {:error, :unavailable}
    end

    def columns(configuration) do
      {:ok, configuration.columns}
    end
  end

  test "shows and clears an activity indicator only for a usable text TTY" do
    stream = stream(:text, tty: true, columns: 80, indicator_delay_ms: 0)
    started = Stream.start(stream)

    assert {:ok, visible} = Stream.tick(started)
    assert_receive {:write, :stdout, "\r\e[2K| Working"}

    assert {:ok, observed} = Stream.observe(visible, {:provider_event, 1, delta("done")})
    assert_receive {:write, :stdout, "\r\e[2K"}
    assert_receive {:write, :stdout, "done"}

    response = response("done")
    assert {:ok, retained} = Stream.observe(observed, {:provider_result, 1, {:ok, response}})
    assert {:ok, _finished} = Stream.finish(retained, {:ok, response})
    assert_receive {:write, :stdout, "\n"}
    refute_receive {:write, _stream, _content}
  end

  test "does not emit indicator controls to JSONL, redirected, or narrow output" do
    for stream <- [
          stream(:jsonl, tty: true, columns: 80, indicator_delay_ms: 0),
          stream(:text, tty: false, columns: 80, indicator_delay_ms: 0),
          stream(:text, tty: true, columns: 39, indicator_delay_ms: 0),
          stream(:text, tty: true, columns: :unavailable, indicator_delay_ms: 0),
          stream(:text, tty: true, columns: 80, indicator_delay_ms: 0, color: :never)
        ] do
      started = Stream.start(stream)
      assert {:ok, _unchanged} = Stream.tick(started)
    end

    refute_receive {:write, _stream, _content}
  end

  test "fails before writing an event that exceeds the output limit" do
    stream = stream(:text, tty: false, columns: 80, maximum_bytes: 3)

    assert {:error, :output_limit, _failed} =
             Stream.observe(stream, {:provider_event, 1, delta("four")})

    refute_receive {:write, _stream, _content}
  end

  test "applies the output limit cumulatively across individually bounded events" do
    stream = stream(:text, tty: false, columns: 80, maximum_bytes: 5)

    assert {:ok, observed} = Stream.observe(stream, {:provider_event, 1, delta("abc")})
    assert_receive {:write, :stdout, "abc"}

    assert {:error, :output_limit, _failed} =
             Stream.observe(observed, {:provider_event, 1, delta("def")})

    refute_receive {:write, _stream, _content}
  end

  test "bounds and then disables indicator output while preserving its final clear" do
    clock = fn ->
      receive do
        {:indicator_time, time} -> time
      end
    end

    stream =
      stream(:text,
        tty: true,
        columns: 80,
        clock: clock,
        indicator_delay_ms: 0,
        indicator_interval_ms: 1,
        indicator_maximum_bytes: 19
      )

    send(self(), {:indicator_time, 0})
    started = Stream.start(stream)
    send(self(), {:indicator_time, 0})
    assert {:ok, visible} = Stream.tick(started)
    assert_receive {:write, :stdout, "\r\e[2K| Working"}

    send(self(), {:indicator_time, 2})
    assert {:ok, exhausted} = Stream.tick(visible)
    assert_receive {:write, :stdout, "\r\e[2K"}
    send(self(), {:indicator_time, 3})
    assert {:ok, _disabled} = Stream.tick(exhausted)
    refute_receive {:write, _stream, _content}
  end

  test "stops after a broken output stream" do
    stream =
      Stream.new(
        :text,
        {SystemAdapter, %{columns: 80, owner: self(), tty: true, write: :closed}},
        indicator_delay_ms: 0
      )

    started = Stream.start(stream)
    assert {:error, :write, failed} = Stream.tick(started)

    assert {:error, :write, ^failed} =
             Stream.observe(failed, {:provider_event, 1, delta("ignored")})
  end

  test "JSONL uses monotonic sequence numbers and exactly one terminal record" do
    stream = stream(:jsonl, tty: true, columns: 80)
    response = response("done")

    assert {:ok, observed} = Stream.observe(stream, {:provider_event, 1, delta("done")})
    assert_receive {:write, :stdout, first}
    assert Jason.decode!(first)["sequence"] == 1

    assert {:ok, retained} =
             Stream.observe(observed, {:provider_result, 1, {:ok, response}})

    assert {:ok, terminal} = Stream.finish(retained, {:ok, response})
    assert_receive {:write, :stdout, second}
    assert %{"sequence" => 2, "type" => "terminal"} = Jason.decode!(second)
    assert {:error, :invalid_event, ^terminal} = Stream.finish(terminal, {:ok, response})
    refute_receive {:write, _stream, _content}
  end

  test "bounds terminal success and failure fields independently of the stream budget" do
    success_stream = stream(:jsonl, tty: false, columns: 80, maximum_bytes: 1)
    response = response(String.duplicate("\\", 100_000))

    assert {:ok, _finished} = Stream.finish(success_stream, {:ok, response})
    assert_receive {:write, :stdout, success_output}
    assert byte_size(success_output) <= 65_536
    assert byte_size(Jason.decode!(success_output)["content"]) <= 8_192

    {:ok, error} =
      Normalized.new(
        :protocol,
        String.duplicate("c", 1_000),
        String.duplicate("m", 100_000)
      )

    failure_stream = stream(:jsonl, tty: false, columns: 80, maximum_bytes: 1)
    assert {:ok, _finished} = Stream.finish(failure_stream, {:error, :execution, error})
    assert_receive {:write, :stdout, failure_output}
    assert byte_size(failure_output) <= 65_536
    failure = Jason.decode!(failure_output)
    assert byte_size(failure["code"]) <= 256
    assert byte_size(failure["message"]) <= 4_096
  end

  defp stream(format, options) do
    configuration = %{
      columns: Keyword.fetch!(options, :columns),
      owner: self(),
      tty: Keyword.fetch!(options, :tty),
      write: :ok
    }

    Stream.new(format, {SystemAdapter, configuration}, options)
  end

  defp delta(content) do
    {:ok, value} = Delta.new(kind: :text, content: content)
    value
  end

  defp response(content) do
    {:ok, assistant} = Conversation.assistant(content: content)
    {:ok, value} = Response.new(message: assistant, finish_reason: :stop)
    value
  end
end
