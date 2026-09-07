defmodule Draught.Session.Runtime.Server do
  @moduledoc false

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
      restart: :transient,
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
    {:ok, State.new(settings)}
  end

  @impl GenServer
  def handle_call({:run, _request, _subscriber}, _from, %State{active: %ActiveTurn{}} = state) do
    {:reply, {:error, Failure.busy()}, state}
  end

  def handle_call({:run, request, subscriber}, _from, %State{active: nil} = state)
      when is_pid(subscriber) do
    subscriber
    |> Process.alive?()
    |> start_turn(state, request, subscriber)
  end

  def handle_call({:run, _request, _subscriber}, _from, %State{} = state) do
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
    :ok = terminal(state, active, outcome)
    {:reply, :ok, State.finish_turn(state, outcome)}
  end

  def handle_call(:stop, _from, %State{} = state) do
    {:stop, :normal, :ok, stop_active(state)}
  end

  @impl GenServer
  def handle_info(
        {:runner_event, token, {:terminal, _outcome}},
        %State{active: %ActiveTurn{token: token}} = state
      ) do
    {:noreply, state}
  end

  def handle_info(
        {:runner_event, token, event},
        %State{active: %ActiveTurn{token: token} = active} = state
      ) do
    :ok = ActiveTurn.deliver(active, state.settings.id, {:runner, active.id, event})
    {:noreply, state}
  end

  def handle_info(
        {reference, outcome},
        %State{active: %ActiveTurn{task: %Task{ref: reference}} = active} = state
      ) do
    :ok = Turn.finish(active)
    :ok = terminal(state, active, outcome)
    {:noreply, State.finish_turn(state, outcome)}
  end

  def handle_info(
        {:DOWN, reference, :process, _pid, _reason},
        %State{active: %ActiveTurn{task: %Task{ref: reference}} = active} = state
      ) do
    :ok = Turn.finish(active)
    outcome = {:error, Failure.turn_failed()}
    :ok = terminal(state, active, outcome)
    {:noreply, State.finish_turn(state, outcome)}
  end

  def handle_info(
        {:turn_timeout, token},
        %State{active: %ActiveTurn{token: token} = active} = state
      ) do
    :ok = Turn.stop(active)
    outcome = {:error, Failure.timeout()}
    :ok = terminal(state, active, outcome)
    {:noreply, State.finish_turn(state, outcome)}
  end

  def handle_info(_message, %State{} = state) do
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, %State{} = state) do
    stop_active(state)
    :ok
  end

  defp start_turn(true, state, request, subscriber) do
    active =
      Turn.start(
        state.settings,
        state.next_turn_id,
        request,
        subscriber,
        self()
      )

    updated = State.start_turn(state, active)
    :ok = ActiveTurn.deliver(active, state.settings.id, {:turn_started, active.id})
    {:reply, {:ok, active.id}, updated}
  end

  defp start_turn(false, state, _request, _subscriber) do
    {:reply, {:error, Failure.invalid_subscriber()}, state}
  end

  defp terminal(state, active, outcome) do
    ActiveTurn.deliver(
      active,
      state.settings.id,
      {:turn_terminal, active.id, outcome}
    )
  end

  defp stop_active(%State{active: nil} = state) do
    state
  end

  defp stop_active(%State{active: %ActiveTurn{} = active} = state) do
    :ok = Turn.stop(active)
    outcome = {:error, Failure.cancelled()}
    :ok = terminal(state, active, outcome)
    State.finish_turn(state, outcome)
  end

  defp via(identifier) do
    {:via, Registry, {Draught.Session.Registry, identifier}}
  end
end
