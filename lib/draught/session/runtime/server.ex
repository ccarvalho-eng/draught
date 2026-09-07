defmodule Draught.Session.Runtime.Server do
  @moduledoc """
  Coordinates one session's turns, cancellation, event delivery, and journal lifecycle.

  The server admits at most one active turn and treats late worker results as stale input.
  """

  use GenServer

  alias Draught.Session.Failure
  alias Draught.Session.Runtime.ActiveTurn
  alias Draught.Session.Runtime.State
  alias Draught.Session.Runtime.Turn
  alias Draught.Session.Settings

  @doc "Returns the dynamic-supervisor child specification for one session."
  @spec child_spec(Settings.t()) :: Supervisor.child_spec()
  def child_spec(%Settings{} = settings) do
    %{
      id: {__MODULE__, settings.id},
      restart: settings.lifecycle.restart,
      shutdown: 5_000,
      start: {__MODULE__, :start_link, [settings]},
      type: :worker
    }
  end

  @doc "Starts one registry-addressed session server."
  @spec start_link(Settings.t()) :: GenServer.on_start()
  def start_link(%Settings{} = settings) do
    GenServer.start_link(__MODULE__, settings, name: via(settings.id))
  end

  @impl GenServer
  def init(%Settings{} = settings) do
    case State.new(settings) do
      {:ok, state} -> initialize_owner(state)
      {:error, error} -> {:stop, {:journal_open_failed, error}}
    end
  end

  @impl GenServer
  def handle_call(
        {operation, _request, _subscriber},
        _from,
        %State{active: %ActiveTurn{}} = state
      )
      when operation in [:run, :run_observed] do
    {:reply, {:error, Failure.busy()}, state}
  end

  def handle_call({:run, request, subscriber}, _from, %State{active: nil} = state)
      when is_pid(subscriber) do
    subscriber
    |> Process.alive?()
    |> start_turn(state, request, subscriber, :asynchronous)
  end

  def handle_call({:run_observed, request, subscriber}, _from, %State{active: nil} = state)
      when is_pid(subscriber) do
    subscriber
    |> Process.alive?()
    |> start_turn(state, request, subscriber, :acknowledged)
  end

  def handle_call({operation, _request, _subscriber}, _from, %State{} = state)
      when operation in [:run, :run_observed] do
    {:reply, {:error, Failure.invalid_subscriber()}, state}
  end

  def handle_call(:status, _from, %State{} = state) do
    {:reply, {:ok, State.status(state)}, state}
  end

  def handle_call(:cancel, _from, %State{active: nil} = state) do
    {:reply, {:error, Failure.no_active_turn()}, state}
  end

  def handle_call(:cancel, _from, %State{active: %ActiveTurn{} = active} = state) do
    :ok = Turn.stop(active)
    outcome = {:error, Failure.cancelled()}

    case persist_terminal(state, active, outcome) do
      {:ok, finished} -> {:reply, :ok, finished}
      {:error, error, failed} -> {:stop, :normal, {:error, error}, failed}
    end
  end

  def handle_call(
        {:runner_event, token, {:terminal, _outcome}},
        _from,
        %State{active: %ActiveTurn{token: token}} = state
      ) do
    {:reply, :ok, state}
  end

  def handle_call(
        {:runner_event, token, {:provider_event, _iteration, _provider_event} = event},
        from,
        %State{active: %ActiveTurn{token: token} = active} = state
      ) do
    deliver_runner(state, active, event, from)
  end

  def handle_call(
        {:runner_event, token, event},
        from,
        %State{active: %ActiveTurn{token: token} = active} = state
      ) do
    journal_event = runner_journal_event(active.id, event)

    case State.record(state, journal_event) do
      {:ok, recorded} ->
        deliver_runner(recorded, active, event, from)

      {:error, error} ->
        runner_journal_failure(state, active, error)
    end
  end

  def handle_call({:runner_event, _token, _event}, _from, %State{} = state) do
    {:reply, :halt, state}
  end

  def handle_call(:checkpoint, _from, %State{} = state) do
    case State.checkpoint(state) do
      {:ok, updated} -> {:reply, :ok, updated}
      {:error, error} -> {:reply, {:error, error}, state}
    end
  end

  def handle_call(:stop, _from, %State{} = state) do
    case stop_active(state) do
      {:ok, stopped} -> {:stop, :normal, :ok, stopped}
      {:error, error, stopped} -> {:stop, :normal, {:error, error}, stopped}
    end
  end

  @impl GenServer
  def handle_info(
        {:DOWN, _reference, :process, owner, _reason},
        %State{settings: %Settings{lifecycle: %{owner: owner}}} = state
      )
      when is_pid(owner) do
    {:stop, :normal, state}
  end

  def handle_info(
        {:runner_ack, acknowledgement, result},
        %State{active: %ActiveTurn{} = active} = state
      )
      when result in [:ok, :halt] do
    case ActiveTurn.acknowledge(active, acknowledgement, result) do
      {:ok, updated} -> {:noreply, State.update_active(state, updated)}
      :stale -> {:noreply, state}
    end
  end

  def handle_info(
        {reference, outcome},
        %State{active: %ActiveTurn{task: %Task{ref: reference}} = active} = state
      ) do
    :ok = Turn.finish(active)

    case persist_terminal(state, active, outcome) do
      {:ok, finished} -> {:noreply, finished}
      {:error, _error, failed} -> {:stop, :normal, failed}
    end
  end

  def handle_info(
        {:DOWN, reference, :process, _pid, _reason},
        %State{active: %ActiveTurn{task: %Task{ref: reference}} = active} = state
      ) do
    :ok = Turn.finish(active)
    outcome = {:error, Failure.turn_failed()}

    case persist_terminal(state, active, outcome) do
      {:ok, finished} -> {:noreply, finished}
      {:error, _error, failed} -> {:stop, :normal, failed}
    end
  end

  def handle_info(
        {:turn_timeout, token},
        %State{active: %ActiveTurn{token: token} = active} = state
      ) do
    :ok = Turn.stop(active)
    outcome = {:error, Failure.timeout()}

    case persist_terminal(state, active, outcome) do
      {:ok, finished} -> {:noreply, finished}
      {:error, _error, failed} -> {:stop, :normal, failed}
    end
  end

  def handle_info(_message, %State{} = state) do
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, %State{} = state) do
    cleanup_active(state)
    :ok
  end

  defp start_turn(true, state, request, subscriber, delivery) do
    turn_id = state.next_turn_id
    provider = Settings.provider_name(state.settings)
    journal_event = {:turn_started, turn_id, provider, request}

    case State.record(state, journal_event) do
      {:ok, recorded} -> start_recorded_turn(recorded, request, subscriber, delivery)
      {:error, error} -> {:stop, :normal, {:error, error}, state}
    end
  end

  defp start_turn(false, state, _request, _subscriber, _delivery) do
    {:reply, {:error, Failure.invalid_subscriber()}, state}
  end

  defp initialize_owner(%State{settings: %Settings{lifecycle: lifecycle}} = state) do
    monitor_owner(lifecycle)
    {:ok, state}
  end

  defp monitor_owner(%{owner: nil}) do
    :ok
  end

  defp monitor_owner(%{owner: owner}) do
    Process.monitor(owner)
    :ok
  end

  defp start_recorded_turn(state, request, subscriber, delivery) do
    active =
      Turn.start(
        state.settings,
        state.next_turn_id,
        request,
        subscriber,
        self(),
        delivery
      )

    updated = State.start_turn(state, active)
    :ok = ActiveTurn.deliver(active, state.settings.id, {:turn_started, active.id})
    {:reply, {:ok, active.id}, updated}
  end

  defp terminal(state, active, outcome) do
    ActiveTurn.deliver(
      active,
      state.settings.id,
      {:turn_terminal, active.id, outcome}
    )
  end

  defp persist_terminal(state, active, outcome) do
    active = ActiveTurn.halt_pending(active)
    event = {:turn_terminal, active.id, outcome}

    case State.record(state, event) do
      {:ok, recorded} ->
        :ok = Turn.complete_span(active, outcome)
        :ok = terminal(recorded, active, outcome)
        {:ok, State.finish_turn(recorded, outcome)}

      {:error, error} ->
        failure = {:error, error}
        :ok = Turn.complete_span(active, failure)
        :ok = terminal(state, active, failure)
        {:error, error, State.finish_turn(state, failure)}
    end
  end

  defp stop_active(%State{active: nil} = state) do
    {:ok, state}
  end

  defp stop_active(%State{active: %ActiveTurn{} = active} = state) do
    :ok = Turn.stop(active)
    outcome = {:error, Failure.cancelled()}
    persist_terminal(state, active, outcome)
  end

  defp runner_journal_failure(state, active, error) do
    :ok = Turn.stop(active)
    outcome = {:error, error}
    :ok = Turn.complete_span(active, outcome)
    :ok = terminal(state, active, outcome)
    failed = State.finish_turn(state, outcome)
    {:stop, :normal, {:error, error}, failed}
  end

  defp runner_journal_event(turn_id, {:provider_result, iteration, outcome}) do
    {:provider_result, turn_id, iteration, outcome}
  end

  defp runner_journal_event(turn_id, {:tool_result, iteration, result}) do
    {:tool_result, turn_id, iteration, result}
  end

  defp cleanup_active(%State{active: nil}) do
    :ok
  end

  defp cleanup_active(%State{active: %ActiveTurn{} = active}) do
    :ok = Turn.stop(active)
    active = ActiveTurn.halt_pending(active)
    Turn.exception_span(active, :exit)
  end

  defp deliver_runner(state, active, event, from) do
    tagged = {:runner, active.id, event}

    case ActiveTurn.deliver_runner(active, state.settings.id, tagged, from) do
      {:delivered, _unchanged} -> {:reply, :ok, state}
      {:pending, updated} -> {:noreply, State.update_active(state, updated)}
    end
  end

  defp via(identifier) do
    {:via, Registry, {Draught.Session.Registry, identifier}}
  end
end
