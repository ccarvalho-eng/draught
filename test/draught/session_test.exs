defmodule Draught.SessionTest do
  use ExUnit.Case, async: true

  alias Draught.Conversation
  alias Draught.Execution.Runner.Limits
  alias Draught.Provider
  alias Draught.Provider.Capabilities
  alias Draught.Provider.Request
  alias Draught.Provider.Response
  alias Draught.Session
  alias Draught.Session.Status
  alias Draught.Tool.Call
  alias Draught.Tool.Definition
  alias Draught.Tool.Execution.Context
  alias Draught.Tool.Execution.Policy
  alias Draught.Tool.Registry

  @receive_timeout 1_000
  @moduletag :tmp_dir

  defmacrop session_event(id, event) do
    quote do
      {:draught_session, ^unquote(id), unquote(event)}
    end
  end

  defmodule ControlledProvider do
    @behaviour Provider

    @impl Provider
    def capabilities(_configuration) do
      Capabilities.new(chat: true, tool_calls: true)
    end

    @impl Provider
    def complete(request, owner) do
      send(owner, {:provider_started, self(), request})

      receive do
        {:provider_result, result} -> result
        {:provider_crash, reason} -> exit(reason)
      end
    end

    @impl Provider
    def stream(_request, _configuration, _sink) do
      {:error, :not_used}
    end
  end

  defmodule BlockingTool do
    @behaviour Draught.Tool.Executor

    @impl Draught.Tool.Executor
    def execute(_call, _context, owner) do
      send(owner, {:tool_started, self()})

      receive do
        :finish -> {:ok, "finished"}
      end
    end
  end

  test "rejects a duplicate session identifier", %{tmp_dir: workspace} do
    id = unique_id()
    configuration = runner_configuration(workspace, {ControlledProvider, self()})
    start_session(id, configuration)

    assert {:error, error} = Session.start(id, configuration)
    assert error.code == "session_already_started"
  end

  test "runs one turn and emits ordered session events", %{tmp_dir: workspace} do
    id = unique_id()
    start_session(id, runner_configuration(workspace, {ControlledProvider, self()}))
    request = request("finish")
    final = response("done")

    assert Session.run(id, request, self()) == {:ok, 1}
    assert_receive session_event(id, {:turn_started, 1})
    assert_receive {:provider_started, provider, ^request}
    send(provider, {:provider_result, {:ok, final}})

    assert_receive session_event(
                     id,
                     {:runner, 1, {:provider_result, 1, {:ok, ^final}}}
                   )

    assert_receive session_event(id, {:turn_terminal, 1, {:ok, ^final}})

    assert {:ok, %Status{} = status} = Session.status(id)
    assert status.phase == :idle
    assert status.active_turn_id == nil
    assert status.last_outcome == {:ok, final}
  end

  test "accepts only one concurrent turn and keeps status responsive", %{tmp_dir: workspace} do
    id = unique_id()
    start_session(id, runner_configuration(workspace, {ControlledProvider, self()}))
    request = request("blocked")
    subscriber = self()

    first = Task.async(fn -> Session.run(id, request, subscriber) end)
    second = Task.async(fn -> Session.run(id, request, subscriber) end)
    results = [Task.await(first), Task.await(second)]

    assert Enum.count(results, &match?({:ok, 1}, &1)) == 1
    assert Enum.count(results, &match?({:error, %{code: "session_busy"}}, &1)) == 1
    assert_receive {:provider_started, provider, ^request}

    assert {:ok, %Status{phase: :running, active_turn_id: 1}} = Session.status(id)
    provider_monitor = Process.monitor(provider)

    assert Session.cancel(id) == :ok
    assert_receive session_event(id, {:turn_terminal, 1, {:error, cancellation}})
    assert cancellation.kind == :cancellation
    assert cancellation.code == "session_cancelled"
    assert_receive {:DOWN, ^provider_monitor, :process, ^provider, :killed}
  end

  test "cancellation propagates through the runner to a tool task", %{tmp_dir: workspace} do
    id = unique_id()
    registry = registry([blocking_definition(self())])

    start_session(
      id,
      runner_configuration(workspace, {ControlledProvider, self()}, registry: registry)
    )

    request = request("use tool")
    call = call("call-1", "blocking_tool")
    tools = tool_response([call])

    assert Session.run(id, request, self()) == {:ok, 1}
    assert_receive session_event(id, {:turn_started, 1})
    assert_receive {:provider_started, provider, provider_request}
    assert provider_request.messages == request.messages
    assert Enum.map(provider_request.tools, & &1.name) == ["blocking_tool"]
    send(provider, {:provider_result, {:ok, tools}})

    assert_receive session_event(
                     id,
                     {:runner, 1, {:provider_result, 1, {:ok, ^tools}}}
                   )

    assert_receive {:tool_started, tool}, @receive_timeout
    tool_monitor = Process.monitor(tool)

    assert Session.cancel(id) == :ok
    assert_receive session_event(id, {:turn_terminal, 1, {:error, cancellation}})
    assert cancellation.code == "session_cancelled"
    assert_receive {:DOWN, ^tool_monitor, :process, ^tool, :killed}, @receive_timeout
  end

  test "whole-turn timeout terminates provider work", %{tmp_dir: workspace} do
    id = unique_id()

    start_session(
      id,
      runner_configuration(workspace, {ControlledProvider, self()}),
      turn_timeout_ms: 100
    )

    request = request("timeout")
    assert Session.run(id, request, self()) == {:ok, 1}
    assert_receive {:provider_started, provider, ^request}
    provider_monitor = Process.monitor(provider)

    assert_receive session_event(id, {:turn_terminal, 1, {:error, timeout}}), 500
    assert timeout.kind == :timeout
    assert timeout.code == "session_timeout"
    assert_receive {:DOWN, ^provider_monitor, :process, ^provider, :killed}
  end

  test "turn worker crash becomes a terminal event without killing the session", %{
    tmp_dir: workspace
  } do
    id = unique_id()
    start_session(id, runner_configuration(workspace, {ControlledProvider, self()}))
    request = request("crash")

    assert Session.run(id, request, self()) == {:ok, 1}
    assert_receive {:provider_started, provider, ^request}
    provider_monitor = Process.monitor(provider)
    {:ok, server} = Session.whereis(id)
    turn_task = :sys.get_state(server).active.task.pid
    Process.exit(turn_task, :boom)

    assert_receive session_event(id, {:turn_terminal, 1, {:error, failure}})
    assert failure.kind == :protocol
    assert failure.code == "session_turn_failed"
    assert_receive {:DOWN, ^provider_monitor, :process, ^provider, :killed}

    assert Process.alive?(server)
    assert {:ok, %Status{phase: :idle, last_outcome: {:error, ^failure}}} = Session.status(id)
  end

  test "late task results cannot overwrite a newer turn", %{tmp_dir: workspace} do
    id = unique_id()
    start_session(id, runner_configuration(workspace, {ControlledProvider, self()}))
    first_request = request("first")

    assert Session.run(id, first_request, self()) == {:ok, 1}
    assert_receive {:provider_started, first_provider, ^first_request}
    first_monitor = Process.monitor(first_provider)
    {:ok, server} = Session.whereis(id)
    first_task_reference = :sys.get_state(server).active.task.ref

    assert Session.cancel(id) == :ok
    assert_receive session_event(id, {:turn_terminal, 1, {:error, _cancellation}})
    assert_receive {:DOWN, ^first_monitor, :process, ^first_provider, :killed}

    second_request = request("second")
    final = response("current")
    stale = response("stale")
    assert Session.run(id, second_request, self()) == {:ok, 2}
    assert_receive {:provider_started, second_provider, ^second_request}

    send(server, {first_task_reference, {:ok, stale}})
    assert {:ok, %Status{phase: :running, active_turn_id: 2}} = Session.status(id)

    send(second_provider, {:provider_result, {:ok, final}})
    assert_receive session_event(id, {:turn_terminal, 2, {:ok, ^final}})
    assert {:ok, %Status{last_outcome: {:ok, ^final}}} = Session.status(id)
  end

  test "completion and cancellation race produces one terminal event", %{tmp_dir: workspace} do
    id = unique_id()
    start_session(id, runner_configuration(workspace, {ControlledProvider, self()}))
    request = request("race")
    final = response("finished")

    assert Session.run(id, request, self()) == {:ok, 1}
    assert_receive {:provider_started, provider, ^request}

    send(provider, {:provider_result, {:ok, final}})
    cancellation = Session.cancel(id)

    assert cancellation == :ok or match?({:error, %{code: "no_active_turn"}}, cancellation)
    assert_receive session_event(id, {:turn_terminal, 1, outcome})

    assert outcome == {:ok, final} or match?({:error, %{code: "session_cancelled"}}, outcome)
    refute_receive session_event(id, {:turn_terminal, 1, _second_outcome}), 50
  end

  defp start_session(id, configuration, options \\ []) do
    assert {:ok, _pid} = Session.start(id, configuration, options)

    on_exit(fn ->
      Session.stop(id)
    end)
  end

  defp runner_configuration(workspace, provider, options \\ []) do
    registry = Keyword.get_lazy(options, :registry, fn -> registry([]) end)
    {:ok, policy} = Policy.new(allowed_risks: [:read])
    {:ok, context} = Context.new(workspace: workspace, policy: policy)

    {:ok, limits} =
      Limits.new(provider_timeout_ms: 5_000, tool_timeout_ms: 5_000)

    [
      provider: provider,
      registry: registry,
      tool_context: context,
      limits: limits
    ]
  end

  defp blocking_definition(owner) do
    {:ok, definition} =
      Definition.new(
        name: "blocking_tool",
        description: "Block until the test releases the tool",
        input_schema: %{"type" => "object"},
        risk: :read,
        executor: {BlockingTool, owner}
      )

    definition
  end

  defp registry(definitions) do
    {:ok, registry} = Registry.new(definitions)
    registry
  end

  defp request(content) do
    {:ok, user} = Conversation.user(content)
    {:ok, request} = Request.new(model: "model", messages: [user])
    request
  end

  defp response(content) do
    {:ok, assistant} = Conversation.assistant(content: content)
    {:ok, response} = Response.new(message: assistant, finish_reason: :stop)
    response
  end

  defp tool_response(calls) do
    {:ok, assistant} = Conversation.assistant(tool_calls: calls)
    {:ok, response} = Response.new(message: assistant, finish_reason: :tool_calls)
    response
  end

  defp call(id, name) do
    {:ok, call} = Call.new(id: id, name: name, arguments: %{})
    call
  end

  defp unique_id do
    suffix = System.unique_integer([:positive, :monotonic])
    "session-#{suffix}"
  end
end
