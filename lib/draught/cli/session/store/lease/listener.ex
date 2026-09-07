defmodule Draught.CLI.Session.Store.Lease.Listener do
  @moduledoc """
  Listens for bounded lease identity probes while a session is exclusively owned.
  """

  alias Draught.CLI.Session.Failure
  alias Draught.CLI.Session.Store.Lease.Endpoint
  alias Draught.CLI.Session.Store.Lease.Probe

  @type entry :: %{acceptor: pid(), monitor: reference(), socket: term()}

  @enforce_keys [:entries]
  defstruct [:entries]

  @type t :: %__MODULE__{entries: [entry()]}

  @doc "Claims the free endpoints in a session rendezvous set after checking all occupied ones."
  @spec open(String.t()) :: {:ok, t()} | {:error, Draught.Error.Normalized.t()}
  def open(key) do
    candidates = Endpoint.candidates(key)
    quorum = div(length(candidates), 2) + 1
    claim(candidates, key, [], quorum)
  end

  @doc "Closes every endpoint and identity responder held by a listener."
  @spec close(t()) :: :ok
  def close(%__MODULE__{entries: entries}) do
    Enum.each(entries, &close_entry/1)
    :ok
  end

  @doc false
  @spec acceptor?(t(), reference(), pid()) :: boolean()
  def acceptor?(%__MODULE__{entries: entries}, reference, pid) do
    Enum.any?(entries, fn entry ->
      entry.monitor == reference and entry.acceptor == pid
    end)
  end

  defp claim([], _key, entries, quorum) do
    finish_claim(entries, length(entries) >= quorum)
  end

  defp claim([port | remaining], key, entries, quorum) do
    case listen(port) do
      {:ok, socket} ->
        {acceptor, monitor} = spawn_monitor(fn -> accept(socket, key) end)
        entry = %{acceptor: acceptor, monitor: monitor, socket: socket}
        claim(remaining, key, [entry | entries], quorum)

      {:error, :eaddrinuse} ->
        occupied(port, remaining, key, entries, quorum)

      {:error, _reason} ->
        close_entries(entries, Failure.storage_unavailable())
    end
  end

  defp listen(port) do
    :gen_tcp.listen(port, [
      :binary,
      active: false,
      exclusiveaddruse: true,
      ip: {127, 0, 0, 1},
      packet: 4,
      packet_size: 256,
      reuseaddr: true
    ])
  end

  defp occupied(port, remaining, key, entries, quorum) do
    case Probe.identity(port, key) do
      :same -> close_entries(entries, Failure.locked())
      :different -> claim(remaining, key, entries, quorum)
      {:error, _reason} -> claim(remaining, key, entries, quorum)
    end
  end

  defp finish_claim(entries, true) do
    {:ok, %__MODULE__{entries: entries}}
  end

  defp finish_claim(entries, false) do
    close_entries(entries, Failure.storage_unavailable())
  end

  defp close_entries(entries, error) do
    Enum.each(entries, &close_entry/1)
    {:error, error}
  end

  defp close_entry(entry) do
    :gen_tcp.close(entry.socket)
    close_acceptor(entry.acceptor, Process.alive?(entry.acceptor))
    Process.demonitor(entry.monitor, [:flush])
  end

  defp accept(listener, key) do
    case :gen_tcp.accept(listener) do
      {:ok, socket} ->
        respond(socket, key)
        accept(listener, key)

      {:error, _reason} ->
        :ok
    end
  end

  defp respond(socket, key) do
    case :gen_tcp.recv(socket, 0, Probe.timeout()) do
      {:ok, request} -> Probe.respond(socket, request, key)
      {:error, _reason} -> :ok
    end

    :gen_tcp.close(socket)
  end

  defp close_acceptor(acceptor, true) do
    Process.exit(acceptor, :shutdown)
  end

  defp close_acceptor(_acceptor, false) do
    :ok
  end
end
