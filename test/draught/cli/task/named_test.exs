defmodule Draught.CLI.Task.NamedTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Configuration
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

    @spec build(Draught.CLI.Configuration.t(), pid()) ::
            {:ok, Selection.t()} | {:error, Draught.CLI.Task.error()}
    def build(configuration, owner) do
      model = configuration.model || "free-model"
      Selection.new({Draught.CLI.Task.NamedTest.CapturingProvider, owner}, model)
    end
  end

  defmodule CapturingProvider do
    @moduledoc false

    @behaviour Provider

    @impl Provider
    def capabilities(_owner) do
      Capabilities.new(chat: true, tool_calls: true)
    end

    @impl Provider
    def complete(request, owner) do
      send(owner, {:provider_request, request})
      {:ok, message} = Conversation.assistant(content: "done")
      Response.new(message: message, finish_reason: :stop)
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
               dependencies
             )

    assert_receive {:provider_request, first_request}
    assert [%System{}, %User{}] = first_request.messages

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
    assert [%System{}, %User{}, %Assistant{}, %User{}] = resumed_request.messages

    assert [%User{content: %Text{text: "Continue"}} | _messages] =
             Enum.reverse(resumed_request.messages)

    assert {:ok, paths} = Paths.new(workspace, "review", environment)

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

  defp dependencies do
    {:ok, dependencies} =
      Dependencies.new(
        [provider: {ProviderBuilder, self()}, identifier: fn -> {:ok, "unused"} end],
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
      risk: :deny,
      origins: %{}
    }
  end

  defp workspace(tmp_dir) do
    path = Path.join(tmp_dir, "workspace")
    File.mkdir_p!(path)
    path
  end
end
