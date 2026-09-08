defmodule Draught.CLI.Interactive.Terminal.Input do
  @moduledoc """
  Owns local terminal reads without blocking the interactive controller.

  Each device has at most one outstanding Erlang I/O request. Abandoned reads
  invalidate that device until it exits; late replies are discarded. Erlang's
  I/O protocol has no cancellation operation, so a restarted coordinator fails
  closed for the remainder of the VM instead of forgetting outstanding reads.
  """

  use GenServer

  alias Draught.CLI.Interactive.Terminal.Adapter
  alias Draught.CLI.Interactive.Terminal.Input.Read

  @maximum_devices 32

  @doc "Starts the supervised input owner with an optional name and ownership identity."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options \\ []) do
    name = Keyword.get(options, :name, __MODULE__)
    identity = Keyword.get(options, :identity, __MODULE__)
    GenServer.start_link(__MODULE__, identity, name: name)
  end

  @doc "Requests one line, delivered asynchronously with its fresh reference."
  @spec request_line(pid(), GenServer.server()) :: {:ok, reference()} | {:error, :io}
  def request_line(device, server \\ __MODULE__) do
    reference = make_ref()
    call(server, {:read, device, reference}, reference)
  end

  @doc "Invalidates an owned pending read without submitting another I/O request."
  @spec cancel_read(reference(), GenServer.server()) :: :ok
  def cancel_read(reference, server \\ __MODULE__) do
    call(server, {:cancel, reference}, reference)
    :ok
  end

  @doc "Waits for a line while preserving coordinator failure as an I/O error."
  @spec read_line(pid(), GenServer.server()) :: Adapter.input_result()
  def read_line(device, server \\ __MODULE__) do
    case GenServer.whereis(server) do
      nil -> {:error, :io}
      owner -> read_monitored(device, owner)
    end
  end

  @impl GenServer
  def init(identity) do
    key = {__MODULE__, identity}
    available = :persistent_term.get(key, :new) == :new
    :persistent_term.put(key, :started)
    {:ok, %{available: available, reads: %{}}}
  end

  @impl GenServer
  def handle_call({:read, device, reference}, {owner, _tag}, state)
      when is_pid(device) and is_reference(reference) do
    occupied = Enum.any?(state.reads, fn {_reference, read} -> read.device == device end)
    available = state.available and not occupied and map_size(state.reads) < @maximum_devices
    begin_read(state, device, owner, reference, available)
  end

  def handle_call({:read, _device, _reference}, _from, state) do
    {:reply, {:error, :io}, state}
  end

  def handle_call({:cancel, reference}, {owner, _tag}, state) do
    {:reply, :ok, revoke(state, reference, owner)}
  end

  @impl GenServer
  def handle_cast({:cancel, owner, reference}, state) do
    {:noreply, revoke(state, reference, owner)}
  end

  @impl GenServer
  def handle_info({:io_reply, reference, result}, state) do
    case Map.get(state.reads, reference) do
      %Read{owner: owner} = read when is_pid(owner) ->
        alive = Process.alive?(owner)
        finish(state, read, result, alive)

      _abandoned ->
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, monitor, :process, _pid, _reason}, state) do
    reads = Enum.reduce(state.reads, %{}, &monitor_down(&1, monitor, &2))
    {:noreply, %{state | reads: reads}}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  defp call(server, request, reference) do
    GenServer.call(server, request)
  catch
    :exit, _reason ->
      GenServer.cast(server, {:cancel, self(), reference})
      {:error, :io}
  end

  defp read_monitored(device, owner) do
    monitor = Process.monitor(owner)

    try do
      case request_line(device, owner) do
        {:ok, reference} -> await(reference, monitor)
        {:error, :io} = error -> error
      end
    after
      Process.demonitor(monitor, [:flush])
    end
  end

  defp await(reference, monitor) do
    receive do
      {:draught_terminal_input, ^reference, result} -> result
      {:DOWN, ^monitor, :process, _owner, _reason} -> {:error, :io}
    end
  end

  defp begin_read(state, device, owner, reference, true) do
    read = Read.new(device, owner, reference)
    send(device, {:io_request, self(), read.reference, {:get_line, :unicode, ""}})
    {:reply, {:ok, read.reference}, put_read(state, read)}
  end

  defp begin_read(state, _device, _owner, _reference, false) do
    {:reply, {:error, :io}, state}
  end

  defp finish(state, read, result, true) do
    send(read.owner, {:draught_terminal_input, read.reference, Read.result(result)})
    Read.release(read)
    {:noreply, %{state | reads: Map.delete(state.reads, read.reference)}}
  end

  defp finish(state, read, _result, false) do
    {:noreply, put_read(state, Read.abandon(read))}
  end

  defp revoke(state, reference, owner) do
    case Map.get(state.reads, reference) do
      %Read{owner: ^owner} = read -> put_read(state, Read.abandon(read))
      _missing -> state
    end
  end

  defp monitor_down({_reference, %Read{device_monitor: monitor} = read}, monitor, reads) do
    Read.unavailable(read)
    Read.release(read)
    reads
  end

  defp monitor_down({reference, %Read{owner_monitor: monitor} = read}, monitor, reads) do
    Map.put(reads, reference, Read.abandon(read))
  end

  defp monitor_down({reference, read}, _monitor, reads) do
    Map.put(reads, reference, read)
  end

  defp put_read(state, read) do
    %{state | reads: Map.put(state.reads, read.reference, read)}
  end
end
