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
  alias Draught.Provider.Ollama.Discovery.HTTP
  alias Draught.Provider.Response

  defmodule SystemAdapter do
    @behaviour Draught.CLI.System.Adapter

    @impl Draught.CLI.System.Adapter
    def cwd(configuration) do
      send(configuration.owner, :interactive_cwd_read)
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
    def write_file(path, content, configuration) do
      send(configuration.owner, {:interactive_file_write, path, content})
      configuration.file_write
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
    def request_line(configuration) do
      reference = make_ref()

      case Map.fetch(configuration, :approval_input) do
        {:ok, input} ->
          send(self(), {:draught_terminal_input, reference, input})
          {:ok, reference}

        :error ->
          {:error, :io}
      end
    end

    @impl Draught.CLI.Interactive.Terminal.Adapter
    def cancel_read(reference, configuration) do
      send(configuration.owner, {:approval_input_cancelled, reference})
      :ok
    end

    @impl Draught.CLI.Interactive.Terminal.Adapter
    def restore(owner) do
      send(owner.owner, :interactive_terminal_restored)
      :ok
    end
  end

  defmodule DiscoveryHTTP do
    @behaviour Draught.Provider.Ollama.Discovery.HTTP

    @impl Draught.Provider.Ollama.Discovery.HTTP
    def request(_method, _url, _body, _configuration) do
      receive do
        {:discovery_response, response} -> response
      end
    end
  end

  defmodule SkillRepository do
    @behaviour Draught.Skill.Repository.Adapter

    @impl Draught.Skill.Repository.Adapter
    def list(_workspace, _environment, configuration) do
      send(configuration.owner, :skills_listed)
      {:ok, configuration.catalog}
    end

    @impl Draught.Skill.Repository.Adapter
    def fetch(name, _workspace, _environment, configuration) do
      send(configuration.owner, {:skill_loaded, name})

      case Map.fetch(configuration.definitions, name) do
        {:ok, definition} -> {:ok, definition}
        :error -> {:error, :not_found}
      end
    end
  end

  defmodule Provider do
    @behaviour Draught.Provider

    alias Draught.Conversation.Content.Text
    alias Draught.Conversation.Message.Tool
    alias Draught.Conversation.Message.User
    alias Draught.Tool.Call

    @impl Draught.Provider
    def capabilities(_configuration) do
      Capabilities.new(chat: true, streaming: true, tool_calls: true)
    end

    @impl Draught.Provider
    def complete(request, {:approval_denial, owner, response}) do
      case Enum.reverse(request.messages) do
        [%Tool{result: result} | _history] ->
          send(owner, {:approval_tool_result, result})
          {:ok, response}

        _messages ->
          {:ok, call} =
            Call.new(
              id: "edit-1",
              name: "replace_in_file",
              arguments: %{
                "path" => "sample.txt",
                "expected" => "before",
                "replacement" => "after"
              }
            )

          {:ok, assistant} = Conversation.assistant(tool_calls: [call])
          Response.new(message: assistant, finish_reason: :tool_calls)
      end
    end

    def complete(request, {:iteration_limit, owner, response}) do
      case current_prompt(request.messages) do
        "exhaust the turn" ->
          iteration_response(request.messages, owner)

        _prompt ->
          send(owner, {:recovery_request, request.messages})
          {:ok, response}
      end
    end

    def complete(request, {:recover, owner, error, response}) do
      send(owner, {:recovery_request, request.messages})

      case current_prompt(request.messages) do
        "fail this turn" -> {:error, error}
        _prompt -> {:ok, response}
      end
    end

    def complete(_request, {:error, error}) do
      {:error, error}
    end

    def complete(_request, response) do
      {:ok, response}
    end

    @impl Draught.Provider
    def stream(request, {:approval_denial, owner, response}, sink) do
      case complete(request, {:approval_denial, owner, response}) do
        {:ok, recovered} -> stream(request, recovered, sink)
        {:error, _error} = result -> result
      end
    end

    def stream(request, {:iteration_limit, owner, response}, sink) do
      case complete(request, {:iteration_limit, owner, response}) do
        {:ok, recovered} -> stream(request, recovered, sink)
        {:error, _error} = result -> result
      end
    end

    def stream(request, {:recover, owner, error, response}, sink) do
      case complete(request, {:recover, owner, error, response}) do
        {:ok, recovered} -> stream(request, recovered, sink)
        {:error, _error} = result -> result
      end
    end

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

    defp current_prompt(messages) do
      messages
      |> Enum.reverse()
      |> Enum.find_value(fn
        %User{content: %Text{text: text}} -> text
        _message -> nil
      end)
    end

    defp iteration_response(messages, owner) do
      iteration = Enum.count(messages, &match?(%Tool{}, &1)) + 1
      send(owner, {:iteration_request, iteration})

      {:ok, call} =
        Call.new(
          id: "read-#{iteration}",
          name: "read_file",
          arguments: %{"path" => "missing-#{iteration}.txt"}
        )

      {:ok, assistant} = Conversation.assistant(tool_calls: [call])
      Response.new(message: assistant, finish_reason: :tool_calls)
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
  test "lists and invokes skills without ending the interactive session", %{
    tmp_dir: temporary_directory
  } do
    metadata = %Draught.Skill.Metadata{
      description: "Review changes",
      name: "review",
      origin: :workspace_draught
    }

    definition = %Draught.Skill.Definition{
      description: metadata.description,
      instructions: "Inspect the complete diff.",
      name: metadata.name,
      origin: metadata.origin
    }

    repository =
      {SkillRepository,
       %{
         catalog: Draught.Skill.Catalog.new([metadata], 0),
         definitions: %{"review" => definition},
         owner: self()
       }}

    {:ok, failure} =
      Normalized.new(:protocol, "provider_failed", "Provider failed", retryable: false)

    input({:ok, "/skills\n"})
    input({:ok, "/skill review\n"})
    input({:ok, "/status\n"})
    input({:ok, "/exit\n"})

    dependencies =
      dependencies(
        cwd: temporary_directory,
        provider_response: {:recover, self(), failure, response()},
        skill_repository: repository,
        state: temporary_directory
      )

    assert CLI.run([], dependencies) == 0
    output = plain(receive_output())

    assert output =~ "Skills:"
    assert output =~ "review"
    assert output =~ "Review changes"
    assert output =~ "Using skill review."
    assert output =~ "Session status"
    assert_receive :skills_listed
    assert_receive {:skill_loaded, "review"}
    assert_receive {:recovery_request, messages}

    assert [prompt] = prompt_contents(messages)
    assert prompt =~ ~s("instructions":"Inspect the complete diff.")
    assert_receive :interactive_terminal_restored
  end

  test "reports an unknown skill and keeps accepting commands" do
    repository =
      {SkillRepository,
       %{catalog: Draught.Skill.Catalog.new([], 0), definitions: %{}, owner: self()}}

    input({:ok, "/skill missing\n"})
    input({:ok, "/status\n"})
    input({:ok, "/exit\n"})

    assert CLI.run([], dependencies(skill_repository: repository)) == 0
    output = plain(receive_output())

    assert output =~ "Skill was not found. Run /skills"
    assert output =~ "Session status"
    assert_receive :interactive_terminal_restored
  end

  @tag :tmp_dir
  test "selects one of several compatible Ollama models inside the shell", %{
    tmp_dir: temporary_directory
  } do
    queue_inventory(["deepseek-r1", "qwen3"])
    queue_inventory(["deepseek-r1", "qwen3"])
    queue_inventory(["qwen3", "deepseek-r1"])
    queue_model()
    input({:ok, "start a task\n"})
    input({:ok, "/model 2\n"})
    input({:ok, "/model\n"})
    input({:ok, "/model 2\n"})
    input({:ok, "/status\n"})
    input({:ok, "/new fresh\n"})
    input({:ok, "/status\n"})
    input({:ok, "/exit\n"})

    dependencies =
      dependencies(
        configuration_home: temporary_directory,
        cwd: temporary_directory,
        provider_factory: :local,
        state: temporary_directory
      )

    assert CLI.run([], dependencies) == 0
    output = plain(receive_output())

    assert output =~ "model:     selection required"
    assert output =~ "Select a model with /model"
    assert output =~ "Run /model before selecting a model by number."
    assert output =~ "Compatible models:"
    assert output =~ "1.   qwen3"
    assert output =~ "2.   deepseek-r1"
    assert output =~ "Selected model deepseek-r1 and saved it as the user default."
    assert output =~ "Model: deepseek-r1"
    assert output =~ "Selected session fresh."
    assert [_first, _second | _remaining] = Regex.scan(~r/Model: deepseek-r1/, output)
    assert_receive :interactive_terminal_restored
  end

  test "automatically selects one compatible Ollama model before opening the shell" do
    queue_inventory(["qwen3"])
    input({:ok, "/status\n"})
    input({:ok, "/exit\n"})

    assert CLI.run([], dependencies(provider_factory: :local)) == 0
    output = plain(receive_output())

    assert output =~ "model:     qwen3"
    assert output =~ "Model: qwen3"
    refute output =~ "selection required"
    assert_receive :interactive_terminal_restored
  end

  @tag :tmp_dir
  test "saves an interactively selected model as the user default", %{
    tmp_dir: temporary_directory
  } do
    queue_inventory(["qwen3", "deepseek-r1"])
    queue_inventory(["qwen3", "deepseek-r1"])
    input({:ok, "/model\n"})
    input({:ok, "/model 2\n"})
    input({:ok, "/exit\n"})

    dependencies =
      dependencies(
        configuration_home: temporary_directory,
        provider_factory: :local
      )

    assert CLI.run([], dependencies) == 0

    path = Path.join([temporary_directory, "draught", "config.json"])
    assert_receive {:interactive_file_write, ^path, content}
    assert {:ok, %{"model" => "deepseek-r1"}} = Jason.decode(content)
    assert_receive :interactive_terminal_restored
  end

  test "keeps the current shell when a fresh session model cannot be prepared" do
    queue_inventory(["qwen3"])
    send(self(), {:discovery_response, {:ok, %HTTP.Response{status: 500, body: ""}}})
    input({:ok, "/new fresh\n"})
    input({:ok, "/status\n"})
    input({:ok, "/exit\n"})

    assert CLI.run([], dependencies(provider_factory: :local)) == 0
    output = plain(receive_output())

    assert output =~ "Session command could not be completed."
    assert output =~ "ID: 00000000-0000-4000-8000-000000000001"
    refute output =~ "Selected session fresh."
    assert_receive :interactive_terminal_restored
  end

  test "keeps model selection unchanged when the user default cannot be saved" do
    queue_inventory(["qwen3", "deepseek-r1"])
    queue_inventory(["qwen3", "deepseek-r1"])
    input({:ok, "/model\n"})
    input({:ok, "/model 2\n"})
    input({:ok, "/status\n"})
    input({:ok, "/exit\n"})

    assert CLI.run([], dependencies(provider_factory: :local)) == 0
    output = plain(receive_output())

    assert output =~
             "Model selection was not changed because the user configuration could not be updated."

    assert output =~ "Model: selection required"
    assert_receive :interactive_terminal_restored
  end

  @tag :tmp_dir
  test "reports an unconfirmed user-default publication without changing shell state", %{
    tmp_dir: temporary_directory
  } do
    queue_inventory(["qwen3", "deepseek-r1"])
    queue_inventory(["qwen3", "deepseek-r1"])
    input({:ok, "/model\n"})
    input({:ok, "/model 2\n"})
    input({:ok, "/status\n"})
    input({:ok, "/exit\n"})

    dependencies =
      dependencies(
        configuration_home: temporary_directory,
        file_write: {:error, :publication_unknown},
        provider_factory: :local
      )

    assert CLI.run([], dependencies) == 0
    output = plain(receive_output())

    assert output =~ "The user configuration update could not be confirmed."
    assert output =~ "Model: selection required"
    assert_receive :interactive_terminal_restored
  end

  @tag :tmp_dir
  test "persists the interactively selected model on the first turn", %{
    tmp_dir: temporary_directory
  } do
    queue_inventory(["qwen3", "deepseek-r1"])
    input({:ok, "/model\n"})
    input({:ok, "/model 2\n"})
    input({:ok, "persist this selection\n"})
    input({:ok, "/sessions\n"})
    input({:ok, "/exit\n"})

    dependencies =
      dependencies(
        configuration_home: temporary_directory,
        cwd: temporary_directory,
        provider_factory: BoundProviderFactory,
        state: temporary_directory
      )

    assert CLI.run(["--model", "qwen3"], dependencies) == 0
    output = plain(receive_output())

    assert output =~ "Selected model deepseek-r1 and saved it as the user default."
    assert output =~ "completed"
    assert output =~ "ollama/deepseek-r1"
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
    assert_receive :interactive_cwd_read
    refute_receive :interactive_cwd_read
    assert_receive :interactive_terminal_restored
  end

  @tag :tmp_dir
  test "persists a session name selected before the first turn", %{
    tmp_dir: temporary_directory
  } do
    identifier = "00000000-0000-4000-8000-000000000001"
    input({:ok, "/rename Review session\n"})
    input({:ok, "create durable history\n"})
    input({:ok, "/sessions\n"})
    input({:ok, "/exit\n"})

    dependencies = dependencies(cwd: temporary_directory, state: temporary_directory)

    assert CLI.run([], dependencies) == 0
    output = plain(receive_output())
    assert output =~ "Session renamed to Review session."
    assert output =~ "1. * Review session  ollama/qwen3"
    refute output =~ "Complete the first turn before renaming"
    assert output =~ "Session ID: #{identifier}"
    assert_receive :interactive_terminal_restored

    assert {:ok, [entry]} =
             Catalog.list(
               {Local, nil},
               temporary_directory,
               environment(state: temporary_directory)
             )

    assert entry.id == identifier
    assert entry.label == "Review session"
    assert entry.preview == "create durable history"
  end

  @tag :tmp_dir
  test "retains a fresh session name when the first provider turn fails", %{
    tmp_dir: temporary_directory
  } do
    {:ok, failure} =
      Normalized.new(:protocol, "provider_failed", "Provider failed", retryable: false)

    input({:ok, "/rename Failed review\n"})
    input({:ok, "fail after initialization\n"})
    input({:ok, "/sessions\n"})
    input({:ok, "/exit\n"})

    dependencies =
      dependencies(
        cwd: temporary_directory,
        provider_response: {:error, failure},
        state: temporary_directory
      )

    assert CLI.run([], dependencies) == 0
    output = plain(receive_output())
    assert output =~ "Task failed (provider_failed)"
    assert output =~ "1. * Failed review  ollama/qwen3"
    assert_receive :interactive_terminal_restored

    assert {:ok, [entry]} =
             Catalog.list(
               {Local, nil},
               temporary_directory,
               environment(state: temporary_directory)
             )

    assert entry.label == "Failed review"
    assert entry.preview == nil
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
  test "keeps the shell usable after a failed turn and resumes clean history", %{
    tmp_dir: temporary_directory
  } do
    {:ok, failure} =
      Normalized.new(:protocol, "provider_failed", "Provider failed", retryable: false)

    input({:ok, "fail this turn\n"})
    input({:ok, "retry cleanly\n"})
    input({:ok, "/exit\n"})

    dependencies =
      dependencies(
        cwd: temporary_directory,
        provider_response: {:recover, self(), failure, response()},
        state: temporary_directory
      )

    assert CLI.run([], dependencies) == 0
    output = receive_output()
    assert output =~ "Task failed (provider_failed)"
    assert output =~ "completed"
    assert output =~ "Session ID: 00000000-0000-4000-8000-000000000001"

    assert_receive {:recovery_request, first_messages}
    assert_receive {:recovery_request, second_messages}
    assert prompt_contents(first_messages) == ["fail this turn"]
    assert prompt_contents(second_messages) == ["retry cleanly"]
    assert_receive :interactive_terminal_restored
  end

  @tag :tmp_dir
  test "stops only the turn at the iteration limit and accepts the next prompt", %{
    tmp_dir: temporary_directory
  } do
    input({:ok, "exhaust the turn\n"})
    input({:ok, "continue after limit\n"})
    input({:ok, "/exit\n"})

    dependencies =
      dependencies(
        cwd: temporary_directory,
        provider_response: {:iteration_limit, self(), response()},
        state: temporary_directory
      )

    assert CLI.run([], dependencies) == 0
    output = receive_output()
    assert output =~ "Task failed (iteration_limit)"
    assert output =~ "completed"
    assert output =~ "Session ID: 00000000-0000-4000-8000-000000000001"

    for iteration <- 1..12 do
      assert_receive {:iteration_request, ^iteration}
    end

    assert_receive {:recovery_request, resumed_messages}
    assert prompt_contents(resumed_messages) == ["continue after limit"]
    assert_receive :interactive_terminal_restored
  end

  @tag :tmp_dir
  test "denies an unapproved edit and keeps the interactive session open", %{
    tmp_dir: temporary_directory
  } do
    path = Path.join(temporary_directory, "sample.txt")
    File.write!(path, "before")
    input({:ok, "edit the file\n"})
    input({:ok, "/status\n"})
    input({:ok, "/exit\n"})

    dependencies =
      dependencies(
        approval_input: {:ok, "\n"},
        cwd: temporary_directory,
        provider_response: {:approval_denial, self(), response()},
        state: temporary_directory
      )

    assert CLI.run([], dependencies) == 0
    output = plain(receive_output())
    assert output =~ "Approval required"
    assert output =~ "Session status"
    assert output =~ "Session ID: 00000000-0000-4000-8000-000000000001"
    assert File.read!(path) == "before"
    assert_receive {:approval_tool_result, %{error: %{code: "approval_denied"}}}
    refute_receive {:approval_input_cancelled, _reference}
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
    input({:ok, "/model other\n"})
    input({:ok, "/exit\n"})
    assert CLI.run(["--resume", identifier], dependencies) == 0
    output = plain(receive_output())
    assert output =~ "model:     qwen3"
    assert output =~ "fixed for this persisted session"
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

    input({:ok, "/resume\n"})
    input({:ok, "/resume 2\n"})
    input({:ok, "/exit\n"})

    assert CLI.run(["--resume", first], dependencies) == 0
    output = plain(receive_output())
    assert output =~ "model:     qwen3"
    assert output =~ "1. * create first  ollama/qwen3"
    assert output =~ "2.   create second  ollama/deepseek-r1"
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
         file_write: Keyword.get(options, :file_write, :ok),
         owner: owner,
         tty: Keyword.get(options, :tty, true)
       }}

    task_dependencies = task_dependencies(provider_factory, provider_response, options)

    {:ok, dependencies} =
      Dependencies.new(
        discovery_http: DiscoveryHTTP,
        skill_repository:
          Keyword.get(
            options,
            :skill_repository,
            {Draught.Skill.Repository.Local, nil}
          ),
        system: system,
        terminal: {
          TerminalAdapter,
          terminal_configuration(options, owner)
        },
        task: task_dependencies
      )

    dependencies
  end

  defp task_dependencies(:local, _provider_response, options) do
    [identifier: identifier(options)]
  end

  defp task_dependencies(provider_factory, provider_response, options) do
    [
      identifier: identifier(options),
      provider: {provider_factory, provider_response}
    ]
  end

  defp terminal_configuration(options, owner) do
    configuration = %{interactive?: Keyword.get(options, :input_terminal, true), owner: owner}

    case Keyword.fetch(options, :approval_input) do
      {:ok, input} -> Map.put(configuration, :approval_input, input)
      :error -> configuration
    end
  end

  defp identifier(options) do
    Keyword.get(
      options,
      :identifier,
      fn -> {:ok, "00000000-0000-4000-8000-000000000001"} end
    )
  end

  defp environment(options) do
    %{}
    |> put_environment(options, :state, "XDG_STATE_HOME")
    |> put_environment(options, :configuration_home, "XDG_CONFIG_HOME")
  end

  defp put_environment(environment, options, option, variable) do
    case Keyword.fetch(options, option) do
      {:ok, value} -> Map.put(environment, variable, value)
      :error -> environment
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

  defp prompt_contents(messages) do
    Enum.flat_map(messages, fn
      %Conversation.Message.User{content: %Conversation.Content.Text{text: text}} -> [text]
      _message -> []
    end)
  end

  defp response do
    {:ok, assistant} = Conversation.assistant(content: "completed")
    {:ok, response} = Response.new(message: assistant, finish_reason: :stop)
    response
  end

  defp queue_inventory(models) do
    queue_list(models)
    Enum.each(models, fn _model -> queue_model() end)
  end

  defp queue_list(models) do
    body = Jason.encode!(%{"models" => Enum.map(models, &%{"name" => &1})})
    send(self(), {:discovery_response, {:ok, %HTTP.Response{status: 200, body: body}}})
  end

  defp queue_model do
    body = Jason.encode!(%{"capabilities" => ["completion", "tools"], "model_info" => %{}})
    send(self(), {:discovery_response, {:ok, %HTTP.Response{status: 200, body: body}}})
  end
end
