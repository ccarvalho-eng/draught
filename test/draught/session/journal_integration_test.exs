defmodule Draught.Session.JournalIntegrationTest do
  use ExUnit.Case, async: true

  alias Draught.Conversation
  alias Draught.Event.Provider.Delta
  alias Draught.Execution.Runner.Limits
  alias Draught.Provider
  alias Draught.Provider.Capabilities
  alias Draught.Provider.Request
  alias Draught.Provider.Response
  alias Draught.Provider.Usage
  alias Draught.Session
  alias Draught.Session.Journal.Local
  alias Draught.Session.Journal.Local.Configuration
  alias Draught.Tool.Execution.Context
  alias Draught.Tool.Execution.Policy
  alias Draught.Tool.Registry

  @receive_timeout 1_000
  @moduletag :tmp_dir

  defmodule ControlledProvider do
    @behaviour Provider

    @impl Provider
    def capabilities(_configuration) do
      Capabilities.new(chat: true, streaming: true, tool_calls: true)
    end

    @impl Provider
    def complete(request, configuration) do
      send(configuration.owner, {:journal_provider_started, self(), request})

      receive do
        {:complete, response} -> {:ok, response}
      end
    end

    @impl Provider
    def stream(request, configuration, sink) do
      send(configuration.owner, {:journal_stream_started, self(), request})

      receive do
        {:stream, events, response} ->
          Enum.each(events, sink)
          {:ok, response}

        {:stream_then_wait, event} ->
          :ok = sink.(event)
          send(configuration.owner, {:journal_stream_waiting, self()})

          receive do
            {:finish_stream, response} -> {:ok, response}
          end
      end
    end
  end

  test "delivers transient provider events without journaling them", %{tmp_dir: workspace} do
    id = unique_id()
    provider_configuration = secret_provider_configuration()
    configuration = runner_configuration(workspace, provider_configuration, :stream)
    request = request("stream")
    final = response("done")
    {:ok, delta} = Delta.new(kind: :text, content: "transient-only")

    assert {:ok, _session} = Session.start(id, configuration)
    assert {:ok, 1} = Session.run(id, request, self())
    assert_receive {:journal_stream_started, provider, ^request}, @receive_timeout
    send(provider, {:stream, [delta], final})

    assert_receive {:draught_session, ^id, {:runner, 1, {:provider_event, 1, ^delta}}},
                   @receive_timeout

    assert_receive {:draught_session, ^id, {:runner, 1, {:provider_result, 1, {:ok, ^final}}}},
                   @receive_timeout

    assert_receive {:draught_session, ^id, {:turn_terminal, 1, {:ok, ^final}}}, @receive_timeout
    assert :ok = Session.stop(id)

    persisted =
      workspace
      |> journal_path(id)
      |> File.read!()

    refute persisted =~ "provider_event"
    refute persisted =~ "transient-only"

    assert {:ok, replay} = Session.replay(workspace, id)
    expected_messages = Enum.concat(request.messages, [final.message])
    assert replay.messages == expected_messages
    assert {:completed, 1, {:ok, ^final}} = replay.terminal
  end

  test "cancellation halts an acknowledged stream before a later turn", %{tmp_dir: workspace} do
    id = unique_id()
    configuration = runner_configuration(workspace, secret_provider_configuration(), :stream)
    first_request = request("cancel while streaming")
    first_delta = delta("partial-visible-output")

    assert {:ok, session} = Session.start(id, configuration)
    assert {:ok, 1} = Session.run_observed(id, first_request, self())
    assert_receive {:draught_session, ^id, {:turn_started, 1}}, @receive_timeout
    assert_receive {:journal_stream_started, provider, ^first_request}, @receive_timeout
    provider_monitor = Process.monitor(provider)
    send(provider, {:stream_then_wait, first_delta})

    assert_receive {:draught_session, ^id,
                    {:runner, 1, {:provider_event, 1, ^first_delta}, first_acknowledgement}},
                   @receive_timeout

    token = :sys.get_state(session).active.token
    assert :ok = Session.cancel(id)

    assert_receive {:draught_session, ^id, {:turn_terminal, 1, {:error, cancellation}}},
                   @receive_timeout

    assert cancellation.code == "session_cancelled"
    refute_receive {:draught_session, ^id, {:turn_terminal, 1, _outcome}}, 50
    assert_receive {:DOWN, ^provider_monitor, :process, ^provider, _reason}, @receive_timeout
    refute_receive {:journal_stream_waiting, ^provider}

    records = journal_records(workspace, id)
    record_types = Enum.map(records, & &1["type"])
    assert record_types == ["turn_started", "turn_terminal"]

    persisted =
      workspace
      |> journal_path(id)
      |> File.read!()

    refute persisted =~ "partial-visible-output"

    stale_event = {:provider_event, 1, first_delta}
    assert GenServer.call(session, {:runner_event, token, stale_event}) == :halt
    refute_receive {:draught_session, ^id, {:runner, 1, _event}}, 50

    second_request = request("continue")
    final = response("continued")
    assert {:ok, 2} = Session.run_observed(id, second_request, self())
    assert_receive {:draught_session, ^id, {:turn_started, 2}}, @receive_timeout
    assert_receive {:journal_stream_started, second_provider, ^second_request}, @receive_timeout
    send(second_provider, {:stream, [], final})

    assert_receive {:draught_session, ^id,
                    {:runner, 2, {:provider_result, 1, {:ok, ^final}}, acknowledgement}},
                   @receive_timeout

    assert :ok = Session.acknowledge(session, first_acknowledgement, :ok)
    refute_receive {:draught_session, ^id, {:turn_terminal, 2, _outcome}}, 50
    assert :ok = Session.acknowledge(session, acknowledgement, :ok)
    assert_receive {:draught_session, ^id, {:turn_terminal, 2, {:ok, ^final}}}, @receive_timeout
    assert :ok = Session.stop(id)

    assert {:ok, replay} = Session.replay(workspace, id)
    assert {:completed, 2, {:ok, ^final}} = replay.terminal
  end

  test "replays canonical state and continues turn identifiers after restart", %{
    tmp_dir: workspace
  } do
    id = unique_id()
    provider_configuration = secret_provider_configuration()
    configuration = runner_configuration(workspace, provider_configuration)
    request = request("first")
    final = response("done")

    assert {:ok, _session} = Session.start(id, configuration)
    assert {:ok, 1} = Session.run(id, request, self())
    assert_receive {:journal_provider_started, provider, ^request}, @receive_timeout
    send(provider, {:complete, final})
    assert_receive {:draught_session, ^id, {:turn_terminal, 1, {:ok, ^final}}}, @receive_timeout
    assert :ok = Session.checkpoint(id)
    assert :ok = Session.stop(id)

    assert {:ok, replay} = Session.replay(workspace, id)
    assert replay.provider == Atom.to_string(ControlledProvider)
    assert replay.model == "model"
    assert replay.messages == Enum.concat(request.messages, [final.message])
    assert replay.usage == final.usage
    assert {:completed, 1, {:ok, ^final}} = replay.terminal
    assert %DateTime{} = replay.created_at
    assert %DateTime{} = replay.updated_at

    journal = journal_path(workspace, id)
    persisted = File.read!(journal)
    refute persisted =~ provider_configuration.api_key
    refute persisted =~ provider_configuration.authorization
    refute persisted =~ provider_configuration.environment_value

    second_request = request("second")
    assert {:ok, _session} = Session.start(id, configuration)
    assert {:ok, 2} = Session.run(id, second_request, self())
    assert_receive {:journal_provider_started, second_provider, ^second_request}, @receive_timeout
    send(second_provider, {:complete, final})
    assert_receive {:draught_session, ^id, {:turn_terminal, 2, {:ok, ^final}}}, @receive_timeout
    assert :ok = Session.stop(id)
  end

  test "a corrupt journal prevents session start without modifying data", %{tmp_dir: workspace} do
    id = unique_id()
    path = journal_path(workspace, id)

    :ok =
      path
      |> Path.dirname()
      |> File.mkdir_p()

    :ok = File.write(path, "partial")
    :ok = File.chmod(path, 0o600)

    before = File.read!(path)
    configuration = runner_configuration(workspace, secret_provider_configuration())

    assert {:error, error} = Session.start(id, configuration)
    assert error.code == "journal_corrupt"
    assert File.read!(path) == before
    assert {:error, %{code: "session_not_found"}} = Session.whereis(id)
  end

  test "records an explicit interruption before continuing a recovered session", %{
    tmp_dir: workspace
  } do
    id = unique_id()
    initial_request = request("interrupted")
    {:ok, journal_configuration} = Configuration.new(workspace, id)
    {:ok, handle, _replay} = Local.open(journal_configuration)

    assert {:ok, _handle} =
             Local.append(
               handle,
               {:turn_started, 1, Atom.to_string(ControlledProvider), initial_request}
             )

    configuration = runner_configuration(workspace, secret_provider_configuration())
    assert {:ok, _session} = Session.start(id, configuration)
    assert {:ok, status} = Session.status(id)
    assert {:error, interruption} = status.last_outcome
    assert interruption.code == "session_interrupted"
    assert :ok = Session.stop(id)

    assert {:ok, replay} = Session.replay(workspace, id)
    assert {:completed, 1, {:error, replayed_interruption}} = replay.terminal
    assert replayed_interruption.code == "session_interrupted"

    assert {:ok, _session} = Session.start(id, configuration)
    second_request = request("continued")
    assert {:ok, 2} = Session.run(id, second_request, self())
    assert_receive {:journal_provider_started, provider, ^second_request}, @receive_timeout
    final = response("continued")
    send(provider, {:complete, final})
    assert_receive {:draught_session, ^id, {:turn_terminal, 2, {:ok, ^final}}}, @receive_timeout
    assert :ok = Session.stop(id)

    assert {:ok, final_replay} = Session.replay(workspace, id)
    assert {:completed, 2, {:ok, ^final}} = final_replay.terminal
  end

  defp runner_configuration(workspace, provider_configuration, provider_mode \\ :complete) do
    {:ok, registry} = Registry.new([])
    {:ok, policy} = Policy.new(allowed_risks: [:read])
    {:ok, context} = Context.new(workspace: workspace, policy: policy)
    {:ok, limits} = Limits.new(provider_timeout_ms: 5_000)

    [
      provider: {ControlledProvider, provider_configuration},
      provider_mode: provider_mode,
      registry: registry,
      tool_context: context,
      limits: limits
    ]
  end

  defp request(content) do
    {:ok, user} = Conversation.user(content)
    {:ok, request} = Request.new(model: "model", messages: [user])
    request
  end

  defp response(content) do
    {:ok, assistant} = Conversation.assistant(content: content)

    {:ok, usage} =
      Usage.new(
        input_tokens: 8,
        output_tokens: 3,
        cached_tokens: 1,
        reasoning_tokens: 1
      )

    {:ok, response} = Response.new(message: assistant, finish_reason: :stop, usage: usage)
    response
  end

  defp delta(content) do
    {:ok, event} = Delta.new(kind: :text, content: content)
    event
  end

  defp journal_records(workspace, id) do
    workspace
    |> journal_path(id)
    |> File.stream!()
    |> Enum.map(&Jason.decode!/1)
  end

  defp secret_provider_configuration do
    %{
      owner: self(),
      api_key: "journal-test-api-secret",
      authorization: "Bearer journal-test-token",
      environment_value: "journal-test-environment-secret"
    }
  end

  defp journal_path(workspace, id) do
    Path.join([workspace, ".draught", "sessions", id, "journal.jsonl"])
  end

  defp unique_id do
    suffix = System.unique_integer([:positive, :monotonic])
    "journal-integration-#{suffix}"
  end
end
