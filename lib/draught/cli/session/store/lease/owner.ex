defmodule Draught.CLI.Session.Store.Lease.Owner do
  @moduledoc false

  use GenServer

  alias Draught.CLI.Session.Store.Lease.Listener

  @enforce_keys [:caller, :caller_monitor, :listener]
  defstruct [:caller, :caller_monitor, :listener]

  @type t :: %__MODULE__{
          caller: pid(),
          caller_monitor: reference(),
          listener: Listener.t()
        }

  @doc "Starts a kernel-lease owner monitoring the acquiring process."
  @spec start(pid(), String.t()) :: GenServer.on_start()
  def start(caller, key) when is_pid(caller) and is_binary(key) do
    GenServer.start(__MODULE__, {caller, key})
  end

  @doc "Fate-shares an opened kernel lease with its acquiring process."
  @spec attach(pid(), pid()) :: :ok
  def attach(owner, caller) when is_pid(owner) and is_pid(caller) do
    GenServer.call(owner, {:attach, caller}, :infinity)
  end

  @impl GenServer
  def init({caller, key}) do
    monitor = Process.monitor(caller)

    case Listener.open(key) do
      {:ok, listener} ->
        {:ok, %__MODULE__{caller: caller, caller_monitor: monitor, listener: listener}}

      {:error, error} ->
        {:stop, error}
    end
  end

  @impl GenServer
  def handle_call({:attach, caller}, _from, %{caller: caller} = state) do
    Process.link(caller)
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call(:release, _from, state) do
    :ok = Listener.close(state.listener)
    {:stop, :normal, :ok, state}
  end

  @impl GenServer
  def handle_info(
        {:DOWN, reference, :process, _pid, _reason},
        %{caller_monitor: reference} = state
      ) do
    {:stop, :normal, state}
  end

  def handle_info({:DOWN, reference, :process, pid, reason}, state) do
    acceptor_result(Listener.acceptor?(state.listener, reference, pid), reason, state)
  end

  @impl GenServer
  def terminate(_reason, state) do
    Listener.close(state.listener)
    :ok
  end

  defp acceptor_result(true, reason, state) do
    {:stop, {:shutdown, {:lease_acceptor_down, reason}}, state}
  end

  defp acceptor_result(false, _reason, state) do
    {:noreply, state}
  end
end
