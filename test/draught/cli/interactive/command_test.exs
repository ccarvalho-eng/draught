defmodule Draught.CLI.Interactive.CommandTest do
  use ExUnit.Case, async: true

  alias Draught.CLI
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Session.Catalog
  alias Draught.CLI.Session.Catalog.Local
  alias Draught.CLI.Task.Provider.Selection
  alias Draught.Conversation
  alias Draught.Error.Normalized
  alias Draught.Event.Provider.Delta
  alias Draught.Provider.Capabilities
  alias Draught.Provider.Response

  defmodule SystemAdapter do
    @behaviour Draught.CLI.System.Adapter

    @impl Draught.CLI.System.Adapter
    def cwd(configuration) do
      {:ok, configuration.cwd}
    end

    @impl Draught.CLI.System.Adapter
    def environment(configuration) do
      configuration.environment
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
    def write(stream, content, configuration) do
      send(configuration.owner, {:interactive_output, stream, IO.iodata_to_binary(content)})
      :ok
    end

    @impl Draught.CLI.System.Adapter
    def tty?(_stream, configuration) do
      configuration.tty
    end

    @impl Draught.CLI.System.Adapter
    def columns(configuration) do
      {:ok, configuration.columns}
    end
  end

  defmodule TerminalAdapter do
    @behaviour Draught.CLI.Interactive.Terminal.Adapter

    @impl Draught.CLI.Interactive.Terminal.Adapter
    def interactive?(configuration) do
      configuration.interactive?
    end

    @impl Draught.CLI.Interactive.Terminal.Adapter
    def read_line(_configuration) do
      receive do
        {:interactive_input, result} -> result
      end
    end

    @impl Draught.CLI.Interactive.Terminal.Adapter
    def restore(owner) do
      send(owner.owner, :interactive_terminal_restored)
      :ok
    end
  end

  defmodule Provider do
    @behaviour Draught.Provider

    @impl Draught.Provider
    def capabilities(_configuration) do
      Capabilities.new(chat: true, streaming: true, tool_calls: true)
    end

    @impl Draught.Provider
    def complete(_request, {:error, error}) do
      {:error, error}
    end

    def complete(_request, response) do
      {:ok, response}
    end

    @impl Draught.Provider
    def stream(_request, {:error, error}, _sink) do
      {:error, error}
    end

    def stream(_request, response, sink) do
      Enum.each(response.message.content, fn
        %Conversation.Content.Text{text: text} ->
          {:ok, event} = Delta.new(kind: :text, content: text)
          :ok = sink.(event)

        _content ->
          :ok
      end)

      {:ok, response}
    end
  end

  defmodule ProviderFactory do
    @behaviour Draught.CLI.Task.Provider.Adapter

    @impl Draught.CLI.Task.Provider.Adapter
    def build(_configuration, response) do
      Selection.new({Provider, response}, "qwen3")
    end
  end

  defmodule BoundProviderFactory do
    @behaviour Draught.CLI.Task.Provider.Adapter

    alias Draught.CLI.Configuration

    @impl Draught.CLI.Task.Provider.Adapter
    def build(%Configuration{model: nil}, _response) do
      {:ok, error} =
        Normalized.new(
          :configuration,
          "model_selection_required",
          "Model selection is required",
          retryable: false
        )

      {:error, error}
    end

    def build(%Configuration{model: model}, response) do
      Selection.new({Provider, response}, model)
    end
  end

  test "opens a session, handles shell commands, and reports its identifier" do
    input({:ok, "/status\n"})
    input({:ok, "/help\n"})
    input({:ok, "/exit\n"})

    assert CLI.run([], dependencies()) == 0
    output = receive_output()
    plain_output = plain(output)

    assert plain_output =~ ">_ Draught"
    assert plain_output =~ "model:     qwen3"
    assert plain_output =~ "Session status"
    assert plain_output =~ "Available commands:"
    assert plain_output =~ "Session ID: 00000000-0000-4000-8000-000000000001"
    assert_receive :interactive_terminal_restored
  end

  @tag :tmp_dir
  test "runs prompts through one persistent named session", %{tmp_dir: temporary_directory} do
    input({:ok, "inspect the workspace\n"})
    input({:ok, "/exit\n"})

    assert CLI.run([], dependencies(cwd: temporary_directory, state: temporary_directory)) == 0
    output = receive_output()

    assert output =~ "completed"
    assert output =~ "Session ID: 00000000-0000-4000-8000-000000000001"

    session =
      Path.join([
        temporary_directory,
        "draught",
        "workspaces"
      ])

    assert File.dir?(session)
    assert_receive :interactive_terminal_restored
  end

  @tag :tmp_dir
  test "manages session labels, archive state, restore, and selection inside the shell", %{
    tmp_dir: temporary_directory
  } do
    first = "00000000-0000-4000-8000-000000000001"
    second = "00000000-0000-4000-8000-000000000002"
    send(self(), {:session_identifier, first})
    send(self(), {:session_identifier, second})

    input({:ok, "create durable history\n"})
    input({:ok, "/rename Review session\n"})
    input({:ok, "/sessions\n"})
    input({:ok, "/archive\n"})
    input({:ok, "/archive Review session\n"})
    input({:ok, "/sessions\n"})
    input({:ok, "/restore Review session\n"})
    input({:ok, "/restore Review session\n"})
    input({:ok, "/resume Review session\n"})
    input({:ok, "/new fresh-session\n"})
    input({:ok, "/resume Review session\n"})
    input({:ok, "/exit\n"})

    identifier = fn ->
      receive do
        {:session_identifier, value} -> {:ok, value}
      end
    end

    dependencies =
      dependencies(
        cwd: temporary_directory,
        identifier: identifier,
        state: temporary_directory
      )

    assert CLI.run([], dependencies) == 0
    output = plain(receive_output())

    assert output =~ "Session renamed to Review session."
    assert output =~ "Sessions:"
    assert output =~ "Archived session #{first}."
    assert output =~ "Restored session #{first}."
    assert [_first_archive, _second_archive] = Regex.scan(~r/Archived session/, output)
    assert [_first_restore, _second_restore] = Regex.scan(~r/Restored session/, output)
    assert output =~ "Selected session fresh-session."
    assert output =~ "Selected session #{first}."
    assert output =~ "Session ID: #{first}"
    assert_receive :interactive_terminal_restored
  end

  @tag :tmp_dir
  test "does not archive the current session when its replacement identifier collides", %{
    tmp_dir: temporary_directory
  } do
    identifier = "00000000-0000-4000-8000-000000000001"
    send(self(), {:session_identifier, identifier})
    send(self(), {:session_identifier, identifier})

    input({:ok, "create durable history\n"})
    input({:ok, "/archive\n"})
    input({:ok, "/exit\n"})

    next_identifier = fn ->
      receive do
        {:session_identifier, value} -> {:ok, value}
      end
    end

    dependencies =
      dependencies(
        cwd: temporary_directory,
        identifier: next_identifier,
        state: temporary_directory
      )

    assert CLI.run([], dependencies) == 0
    output = plain(receive_output())
    assert output =~ "That session ID already exists."
    assert output =~ "Session ID: #{identifier}"
    assert_receive :interactive_terminal_restored

    input({:ok, "/exit\n"})
    assert CLI.run(["--resume", identifier], dependencies) == 0
    assert plain(receive_output()) =~ "Session ID: #{identifier}"
    assert_receive :interactive_terminal_restored
  end

  test "rejects interactive JSON Lines and non-terminal execution before reading input" do
    assert CLI.run(["--output", "jsonl"], dependencies()) == 2
    assert receive_output() =~ "does not support JSON Lines"
    refute_receive :interactive_terminal_restored

    assert CLI.run([], dependencies(tty: false)) == 2
    assert receive_output() =~ "requires a terminal"
    refute_receive :interactive_terminal_restored

    assert CLI.run([], dependencies(input_terminal: false)) == 2
    assert receive_output() =~ "requires a terminal"
    refute_receive :interactive_terminal_restored
  end

  test "closes cleanly on end of input" do
    input(:eof)

    assert CLI.run([], dependencies()) == 0
    assert receive_output() =~ "Session ID: 00000000-0000-4000-8000-000000000001"
    assert_receive :interactive_terminal_restored
  end

  @tag :tmp_dir
  test "closes a failed turn without guessing whether it can be resumed", %{
    tmp_dir: temporary_directory
  } do
    {:ok, failure} =
      Normalized.new(:protocol, "provider_failed", "Provider failed", retryable: false)

    input({:ok, "run the task\n"})

    dependencies =
      dependencies(
        cwd: temporary_directory,
        provider_response: {:error, failure},
        state: temporary_directory
      )

    assert CLI.run([], dependencies) == 4
    output = receive_output()
    assert output =~ "Task failed (provider_failed)"
    assert output =~ "Session ID: 00000000-0000-4000-8000-000000000001"
    assert_receive :interactive_terminal_restored
  end

  @tag :tmp_dir
  test "loads a recorded model before provider selection on interactive resume", %{
    tmp_dir: temporary_directory
  } do
    identifier = "00000000-0000-4000-8000-000000000001"

    dependencies =
      dependencies(
        cwd: temporary_directory,
        provider_factory: BoundProviderFactory,
        state: temporary_directory
      )

    assert CLI.run(
             ["--session", identifier, "--model", "qwen3", "create the session"],
             dependencies
           ) == 0

    assert receive_output() =~ "completed"
    input({:ok, "/exit\n"})
    assert CLI.run(["--resume", identifier], dependencies) == 0
    output = plain(receive_output())
    assert output =~ "model:     qwen3"
    assert output =~ "Session ID: #{identifier}"
    assert_receive :interactive_terminal_restored

    assert CLI.run(["--resume", identifier, "--model", "other"], dependencies) == 5
    assert receive_output() =~ "Task execution configuration is invalid"
    refute_receive :interactive_terminal_restored
  end

  @tag :tmp_dir
  test "switches between sessions using each durable model binding", %{
    tmp_dir: temporary_directory
  } do
    first = "00000000-0000-4000-8000-000000000001"
    second = "00000000-0000-4000-8000-000000000002"

    dependencies =
      dependencies(
        cwd: temporary_directory,
        provider_factory: BoundProviderFactory,
        state: temporary_directory
      )

    assert CLI.run(
             ["--session", first, "--model", "qwen3", "create first"],
             dependencies
           ) == 0

    assert receive_output() =~ "completed"

    assert CLI.run(
             ["--session", second, "--model", "deepseek-r1", "create second"],
             dependencies
           ) == 0

    assert receive_output() =~ "completed"

    input({:ok, "/resume #{second}\n"})
    input({:ok, "/exit\n"})

    assert CLI.run(["--resume", first], dependencies) == 0
    output = plain(receive_output())
    assert output =~ "model:     qwen3"
    assert output =~ "Selected session #{second}."
    assert output =~ "Model: deepseek-r1"
    assert output =~ "Session ID: #{second}"
    assert_receive :interactive_terminal_restored
  end

  @tag :tmp_dir
  test "rejects a missing resume target before opening the prompt", %{
    tmp_dir: temporary_directory
  } do
    dependencies =
      dependencies(
        cwd: temporary_directory,
        provider_factory: BoundProviderFactory,
        state: temporary_directory
      )

    assert CLI.run(["--resume", "missing-session"], dependencies) == 5
    assert receive_output() =~ "Task execution configuration is invalid"
    refute_receive :interactive_terminal_restored
  end

  @tag :tmp_dir
  test "rejects headless resume of an archived session before provider execution", %{
    tmp_dir: temporary_directory
  } do
    identifier = "00000000-0000-4000-8000-000000000001"

    dependencies =
      dependencies(
        cwd: temporary_directory,
        provider_factory: BoundProviderFactory,
        state: temporary_directory
      )

    assert CLI.run(
             ["--session", identifier, "--model", "qwen3", "create the session"],
             dependencies
           ) == 0

    assert receive_output() =~ "completed"
    session_environment = environment(state: temporary_directory)

    assert {:ok, _entry} =
             Catalog.archive(
               {Local, nil},
               temporary_directory,
               identifier,
               session_environment
             )

    assert CLI.run(["--resume", identifier, "continue"], dependencies) == 5
    assert receive_output() =~ "session_archived"
    refute_receive :interactive_terminal_restored
  end

  defp dependencies(options \\ []) do
    provider_response = Keyword.get_lazy(options, :provider_response, &response/0)
    provider_factory = Keyword.get(options, :provider_factory, ProviderFactory)
    owner = self()

    system =
      {SystemAdapter,
       %{
         columns: 50,
         cwd: Keyword.get(options, :cwd, "/workspace"),
         environment: environment(options),
         owner: owner,
         tty: Keyword.get(options, :tty, true)
       }}

    {:ok, dependencies} =
      Dependencies.new(
        system: system,
        terminal: {
          TerminalAdapter,
          %{interactive?: Keyword.get(options, :input_terminal, true), owner: owner}
        },
        task: [
          identifier:
            Keyword.get(
              options,
              :identifier,
              fn -> {:ok, "00000000-0000-4000-8000-000000000001"} end
            ),
          provider: {provider_factory, provider_response}
        ]
      )

    dependencies
  end

  defp environment(options) do
    case Keyword.fetch(options, :state) do
      {:ok, state} -> %{"XDG_STATE_HOME" => state}
      :error -> %{}
    end
  end

  defp input(result) do
    send(self(), {:interactive_input, result})
  end

  defp receive_output do
    receive_output([])
  end

  defp receive_output(records) do
    receive do
      {:interactive_output, _stream, content} ->
        receive_output([content | records])
    after
      0 ->
        records
        |> Enum.reverse()
        |> IO.iodata_to_binary()
    end
  end

  defp plain(output) do
    Regex.replace(~r/\e\[[0-9;]*m/, output, "")
  end

  defp response do
    {:ok, assistant} = Conversation.assistant(content: "completed")
    {:ok, response} = Response.new(message: assistant, finish_reason: :stop)
    response
  end
end
