defmodule Draught.CLI.Task.NamedTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Configuration
  alias Draught.CLI.Session.Catalog.Preview
  alias Draught.CLI.Session.Store.Paths
  alias Draught.CLI.Task.Dependencies
  alias Draught.CLI.Task.Named
  alias Draught.CLI.Task.Provider.Selection
  alias Draught.Conversation
  alias Draught.Conversation.Content.Text
  alias Draught.Conversation.Message.Assistant
  alias Draught.Conversation.Message.System
  alias Draught.Conversation.Message.User
  alias Draught.Provider
  alias Draught.Provider.Capabilities
  alias Draught.Provider.Response
  alias Draught.Session.Journal
  alias Draught.Session.Journal.Local

  @moduletag :tmp_dir

  defmodule ProviderBuilder do
    @moduledoc false

    @spec build(Draught.CLI.Configuration.t(), pid() | {pid(), keyword()}) ::
            {:ok, Selection.t()} | {:error, Draught.CLI.Task.error()}
    def build(configuration, provider_configuration) do
      model = configuration.model || "free-model"

      Selection.new(
        {Draught.CLI.Task.NamedTest.CapturingProvider, provider_configuration},
        model
      )
    end
  end

  defmodule CapturingProvider do
    @moduledoc false

    @behaviour Provider

    @impl Provider
    def capabilities(owner) when is_pid(owner) do
      Capabilities.new(chat: true, tool_calls: true)
    end

    def capabilities({_owner, capabilities}) do
      Capabilities.new(capabilities)
    end

    @impl Provider
    def complete(request, owner) when is_pid(owner) do
      send(owner, {:provider_request, request})
      {:ok, message} = Conversation.assistant(content: "done")
      Response.new(message: message, finish_reason: :stop)
    end

    def complete(request, {owner, _capabilities}) do
      complete(request, owner)
    end

    @impl Provider
    def stream(_request, _owner, _sink) do
      {:error, :not_used}
    end
  end

  test "creates and resumes a named session with complete conversation history", %{
    tmp_dir: tmp_dir
  } do
    workspace = workspace(tmp_dir)
    environment = %{"XDG_STATE_HOME" => Path.join(tmp_dir, "state")}
    configuration = configuration("free-model")
    dependencies = dependencies()

    assert {:ok, %Response{}} =
             Named.run(
               :create,
               "review",
               "Inspect",
               configuration,
               workspace,
               environment,
               dependencies,
               "original instructions"
             )

    assert_receive {:provider_request, first_request}

    assert [%System{content: %Text{text: "original instructions"}}, %User{}] =
             first_request.messages

    assert {:ok, %Response{}} =
             Named.run(
               :resume,
               "review",
               "Continue",
               configuration,
               workspace,
               environment,
               dependencies
             )

    assert_receive {:provider_request, resumed_request}

    assert [
             %System{content: %Text{text: "original instructions"}},
             %User{},
             %Assistant{},
             %User{}
           ] = resumed_request.messages

    assert [%User{content: %Text{text: "Continue"}} | _messages] =
             Enum.reverse(resumed_request.messages)

    assert {:ok, paths} = Paths.new(workspace, "review", environment)
    assert {:ok, %Preview{text: "Continue"}} = Preview.Local.read(paths)

    workspace_state = Path.join(workspace, ".draught")
    refute File.exists?(workspace_state)

    assert {:ok, journal_configuration} =
             Draught.Session.Journal.Local.Configuration.from_directory("review", paths.session)

    assert {:ok, replay} = Journal.replay({Local, journal_configuration})
    assert replay.last_turn_id == 2
  end

  test "rejects model drift before executing a resumed session", %{tmp_dir: tmp_dir} do
    workspace = workspace(tmp_dir)
    environment = %{"XDG_STATE_HOME" => Path.join(tmp_dir, "state")}
    dependencies = dependencies()

    assert {:ok, %Response{}} =
             Named.run(
               :create,
               "review",
               "Inspect",
               configuration("free-model"),
               workspace,
               environment,
               dependencies
             )

    assert_receive {:provider_request, _request}

    assert {:error, :session, error} =
             Named.run(
               :resume,
               "review",
               "Continue",
               configuration("different-model"),
               workspace,
               environment,
               dependencies
             )

    assert error.code == "session_binding_mismatch"
    refute_receive {:provider_request, _request}

    assert {:ok, %Response{}} =
             Named.run(
               :resume,
               "review",
               "Continue",
               configuration(nil),
               workspace,
               environment,
               dependencies
             )

    assert_receive {:provider_request, resumed_request}
    assert resumed_request.model == "free-model"
  end

  test "rejects capability drift before executing a resumed session", %{tmp_dir: tmp_dir} do
    workspace = workspace(tmp_dir)
    environment = %{"XDG_STATE_HOME" => Path.join(tmp_dir, "state")}
    initial = [chat: true, streaming: true, tool_calls: true]
    changed = [chat: true, streaming: false, tool_calls: true]

    assert {:ok, %Response{}} =
             Named.run(
               :create,
               "review",
               "Inspect",
               configuration("free-model"),
               workspace,
               environment,
               dependencies({self(), initial})
             )

    assert_receive {:provider_request, _request}
    assert {:ok, paths} = Paths.new(workspace, "review", environment)
    journal_before = File.read!(paths.journal)

    assert {:error, :session, error} =
             Named.run(
               :resume,
               "review",
               "Continue",
               configuration("free-model"),
               workspace,
               environment,
               dependencies({self(), changed})
             )

    assert error.code == "session_binding_mismatch"
    refute_receive {:provider_request, _request}
    assert File.read!(paths.journal) == journal_before

    assert {:ok, %Response{}} =
             Named.run(
               :resume,
               "review",
               "Continue",
               configuration("free-model"),
               workspace,
               environment,
               dependencies({self(), initial})
             )

    assert_receive {:provider_request, _request}
  end

  test "upgrades a legacy binding during its first verified resume", %{tmp_dir: tmp_dir} do
    workspace = workspace(tmp_dir)
    environment = %{"XDG_STATE_HOME" => Path.join(tmp_dir, "state")}
    configuration = configuration("free-model")
    dependencies = dependencies()

    assert {:ok, %Response{}} =
             Named.run(
               :create,
               "review",
               "Inspect",
               configuration,
               workspace,
               environment,
               dependencies
             )

    assert_receive {:provider_request, _request}
    assert {:ok, paths} = Paths.new(workspace, "review", environment)
    downgrade_binding(paths.binding)

    assert {:ok, %Response{}} =
             Named.run(
               :resume,
               "review",
               "Continue",
               configuration,
               workspace,
               environment,
               dependencies
             )

    assert_receive {:provider_request, _request}
    assert {:ok, upgraded} = Draught.CLI.Session.Binding.Local.read(paths)
    assert upgraded.version == 2
    assert is_binary(upgraded.capabilities)
  end

  defp dependencies(provider_configuration \\ self()) do
    {:ok, dependencies} =
      Dependencies.new(
        [
          provider: {ProviderBuilder, provider_configuration},
          identifier: fn -> {:ok, "unused"} end
        ],
        Draught.Provider.Ollama.Discovery.HTTP.Req
      )

    dependencies
  end

  defp configuration(model) do
    %Configuration{
      profile: "test",
      provider: :ollama,
      base_url: "http://localhost:11434",
      model: model,
      credential: nil,
      headers: %{},
      web: false,
      web_search: false,
      risk: :deny,
      origins: %{}
    }
  end

  defp workspace(tmp_dir) do
    path = Path.join(tmp_dir, "workspace")
    File.mkdir_p!(path)
    path
  end

  defp downgrade_binding(path) do
    legacy =
      path
      |> File.read!()
      |> Jason.decode!()
      |> Map.delete("capabilities")
      |> Map.put("schema", "draught.cli.session/v1")
      |> Jason.encode!()

    File.write!(path, legacy)
    File.chmod!(path, 0o600)
  end
end
