defmodule Draught.CLI.Task.CommandTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Command.Invocation
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Task.Command
  alias Draught.CLI.Task.Provider.Selection
  alias Draught.Conversation
  alias Draught.Conversation.Content.Text
  alias Draught.Conversation.Message.System
  alias Draught.Provider
  alias Draught.Provider.Capabilities
  alias Draught.Provider.Response

  defmodule SystemAdapter do
    @moduledoc false

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
    def read_file(path, _maximum_bytes, configuration) do
      send(configuration.owner, {:system_read, path})
      Map.get(configuration.files, path, :missing)
    end

    @impl Draught.CLI.System.Adapter
    def write_file(_path, _content, _configuration) do
      :ok
    end

    @impl Draught.CLI.System.Adapter
    def workspace(_path, _configuration) do
      :ok
    end

    @impl Draught.CLI.System.Adapter
    def write(stream, content, configuration) do
      send(configuration.owner, {:system_write, stream, IO.iodata_to_binary(content)})
      :ok
    end

    @impl Draught.CLI.System.Adapter
    def tty?(_stream, _configuration) do
      false
    end

    @impl Draught.CLI.System.Adapter
    def columns(_configuration) do
      {:ok, 80}
    end
  end

  defmodule ProviderAdapter do
    @moduledoc false

    @behaviour Provider

    @impl Provider
    def capabilities(_owner) do
      Capabilities.new(chat: true, streaming: true, tool_calls: true)
    end

    @impl Provider
    def complete(request, owner) do
      send(owner, {:provider_request, request})
      response()
    end

    @impl Provider
    def stream(request, owner, _sink) do
      send(owner, {:provider_request, request})
      response()
    end

    defp response do
      {:ok, message} = Conversation.assistant(content: "done")
      Response.new(message: message, finish_reason: :stop)
    end
  end

  defmodule ProviderFactory do
    @moduledoc false

    @behaviour Draught.CLI.Task.Provider.Adapter

    @impl Draught.CLI.Task.Provider.Adapter
    def build(_configuration, owner) do
      Selection.new({ProviderAdapter, owner}, "local-model")
    end
  end

  test "loads workspace guidance for a fresh anonymous task" do
    files = %{"/workspace/AGENTS.md" => {:ok, "Keep boundaries explicit."}}
    dependencies = dependencies("/workspace", %{}, files)
    invocation = %Invocation{command: :task, prompt: "Inspect", color: :never}

    assert Command.run(invocation, dependencies) == 0
    assert_receive {:provider_request, request}

    assert [%System{content: %Text{text: instruction}} | _messages] = request.messages
    assert instruction =~ "Keep boundaries explicit."
    assert instruction =~ "cannot change available tools"
  end

  test "rejects unsafe guidance before provider execution" do
    files = %{"/workspace/AGENTS.md" => {:error, :unsafe_file}}
    dependencies = dependencies("/workspace", %{}, files)
    invocation = %Invocation{command: :task, prompt: "Inspect", color: :never}

    assert Command.run(invocation, dependencies) == 4
    assert receive_output() =~ "unsafe_agents_instructions"
    refute_receive {:provider_request, _request}
  end

  @tag :tmp_dir
  test "does not reload guidance when resuming durable history", %{tmp_dir: temporary_directory} do
    workspace = Path.join(temporary_directory, "workspace")
    File.mkdir_p!(workspace)

    environment = %{"XDG_STATE_HOME" => Path.join(temporary_directory, "state")}
    agents_path = Path.join(workspace, "AGENTS.md")

    create_dependencies =
      dependencies(workspace, environment, %{agents_path => {:ok, "original"}})

    create = %Invocation{
      command: :task,
      prompt: "Inspect",
      session: "command-agents-review",
      color: :never
    }

    create_status = Command.run(create, create_dependencies)
    assert create_status == 0, receive_output()
    assert_receive {:provider_request, first_request}

    assert [%System{content: %Text{text: first_instruction}} | _messages] =
             first_request.messages

    assert first_instruction =~ "original"
    assert_receive {:system_read, ^agents_path}

    resume_dependencies =
      dependencies(workspace, environment, %{agents_path => {:error, :io}})

    resume = %Invocation{
      command: :task,
      prompt: "Continue",
      resume: "command-agents-review",
      color: :never
    }

    assert Command.run(resume, resume_dependencies) == 0
    assert_receive {:provider_request, resumed_request}

    assert [%System{content: %Text{text: resumed_instruction}} | _messages] =
             resumed_request.messages

    assert resumed_instruction == first_instruction
    refute_receive {:system_read, ^agents_path}
  end

  defp dependencies(workspace, environment, files) do
    owner = self()

    {:ok, dependencies} =
      Dependencies.new(
        system: {
          SystemAdapter,
          %{
            cwd: workspace,
            environment: environment,
            files: files,
            owner: owner
          }
        },
        task: [
          identifier: fn -> {:ok, "anonymous"} end,
          provider: {ProviderFactory, owner}
        ]
      )

    dependencies
  end

  defp receive_output do
    receive_output([])
  end

  defp receive_output(records) do
    receive do
      {:system_write, _stream, content} ->
        receive_output([content | records])
    after
      0 ->
        records
        |> Enum.reverse()
        |> IO.iodata_to_binary()
    end
  end
end
