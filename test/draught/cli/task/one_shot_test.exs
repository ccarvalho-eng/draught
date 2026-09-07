defmodule Draught.CLI.Task.OneShotTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Task.OneShot
  alias Draught.CLI.Task.Preparation
  alias Draught.CLI.Task.Provider.Selection
  alias Draught.Conversation
  alias Draught.Provider
  alias Draught.Provider.Capabilities
  alias Draught.Provider.Fake
  alias Draught.Provider.Request
  alias Draught.Provider.Response
  alias Draught.Session
  alias Draught.Tool.Builtin
  alias Draught.Tool.Registry

  @receive_timeout 1_000
  @moduletag :tmp_dir

  defmodule BlockingProvider do
    @behaviour Provider

    @impl Provider
    def capabilities(_configuration) do
      Capabilities.new(chat: true, tool_calls: true)
    end

    @impl Provider
    def complete(_request, owner) do
      send(owner, {:provider_started, self()})

      receive do
        {:complete, result} -> result
      end
    end

    @impl Provider
    def stream(_request, _configuration, _sink) do
      {:error, :not_used}
    end
  end

  test "executes through a supervised session and leaves no journal", %{tmp_dir: workspace} do
    {preparation, response} = completed_preparation(workspace)

    assert {:ok, ^response} = OneShot.run("one-shot-test", preparation)
    assert {:error, %{code: "session_not_found"}} = Session.whereis("one-shot-test")

    journal_directory = Path.join(workspace, ".draught")
    refute File.exists?(journal_directory)
  end

  test "identifies a session-start failure separately from execution", %{tmp_dir: workspace} do
    {preparation, _response} = completed_preparation(workspace)

    assert {:ok, _session} =
             Session.start("duplicate-one-shot", preparation.runner, preparation.session_options)

    on_exit(fn -> Session.stop("duplicate-one-shot") end)

    assert {:error, :session, %{code: "session_already_started"}} =
             OneShot.run("duplicate-one-shot", preparation)
  end

  test "owner death terminates its temporary session and active work", %{tmp_dir: workspace} do
    preparation = blocking_preparation(workspace)
    identifier = unique_identifier("owner-death")

    caller =
      Task.Supervisor.async_nolink(Draught.Execution.TaskSupervisor, fn ->
        OneShot.run(identifier, preparation)
      end)

    assert_receive {:provider_started, provider}, @receive_timeout
    assert {:ok, session} = Session.whereis(identifier)
    provider_monitor = Process.monitor(provider)
    session_monitor = Process.monitor(session)

    Process.exit(caller.pid, :kill)

    assert_receive {:DOWN, caller_reference, :process, _pid, :killed}, @receive_timeout
    assert caller_reference == caller.ref
    assert_receive {:DOWN, ^session_monitor, :process, ^session, :normal}, @receive_timeout
    assert_process_stopped(provider_monitor, provider)
    assert {:error, %{code: "session_not_found"}} = Session.whereis(identifier)
  end

  test "an abnormal temporary-session exit is not restarted", %{tmp_dir: workspace} do
    preparation = blocking_preparation(workspace)
    identifier = unique_identifier("abnormal-exit")

    caller =
      Task.Supervisor.async_nolink(Draught.Execution.TaskSupervisor, fn ->
        OneShot.run(identifier, preparation)
      end)

    assert_receive {:provider_started, provider}, @receive_timeout
    assert {:ok, session} = Session.whereis(identifier)
    provider_monitor = Process.monitor(provider)

    Process.exit(session, :boom)

    assert {:error, :session, error} = Task.await(caller)
    assert error.code in ["session_call_failed", "task_session_stopped"]
    assert_process_stopped(provider_monitor, provider)
    assert {:error, %{code: "session_not_found"}} = Session.whereis(identifier)
  end

  defp blocking_preparation(workspace) do
    assert {:ok, selection} = Selection.new({BlockingProvider, self()}, "free-model")
    assert {:ok, preparation} = Preparation.new("Inspect", selection, workspace)
    preparation
  end

  defp completed_preparation(workspace) do
    request = completed_request()
    response = completed_response()
    provider = completed_provider(request, response)
    assert {:ok, selection} = Selection.new({Fake, provider}, "free-model")
    assert {:ok, preparation} = Preparation.new("Inspect", selection, workspace)
    {preparation, response}
  end

  defp completed_provider(request, response) do
    assert {:ok, provider} = Fake.new(completions: [[request: request, response: response]])
    provider
  end

  defp completed_request do
    assert {:ok, system} = Conversation.system(Preparation.system_prompt())
    assert {:ok, user} = Conversation.user("Inspect")
    assert {:ok, registry} = Builtin.registry()

    assert {:ok, request} =
             Request.new(
               model: "free-model",
               messages: [system, user],
               tools: Registry.specifications(registry)
             )

    request
  end

  defp completed_response do
    assert {:ok, assistant} = Conversation.assistant(content: "Done")
    assert {:ok, response} = Response.new(message: assistant, finish_reason: :stop)
    response
  end

  defp unique_identifier(prefix) do
    suffix = System.unique_integer([:positive, :monotonic])
    "#{prefix}-#{suffix}"
  end

  defp assert_process_stopped(monitor, process) do
    assert_receive {:DOWN, ^monitor, :process, ^process, reason}, @receive_timeout
    assert reason in [:killed, :noproc]
  end
end
