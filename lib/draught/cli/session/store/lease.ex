defmodule Draught.CLI.Session.Store.Lease do
  @moduledoc false

  alias Draught.CLI.Session.Failure
  alias Draught.CLI.Session.Store.Lease.Owner
  alias Draught.CLI.Session.Store.Paths

  @enforce_keys [:monitor, :owner]
  defstruct [:monitor, :owner]

  @type t :: %__MODULE__{monitor: reference(), owner: pid()}

  @doc "Acquires a kernel-held exclusive lease for one persistent session."
  @spec acquire(Paths.t()) :: {:ok, t()} | {:error, Draught.Error.Normalized.t()}
  def acquire(%Paths{} = paths) do
    case Owner.start(self(), paths.key) do
      {:ok, owner} ->
        attach(owner)

      {:error, %Draught.Error.Normalized{} = error} ->
        {:error, error}

      {:error, _reason} ->
        {:error, Failure.storage_unavailable()}
    end
  end

  @doc "Releases a previously acquired session lease."
  @spec release(t()) :: :ok | {:error, Draught.Error.Normalized.t()}
  def release(%__MODULE__{} = lease) do
    result = GenServer.call(lease.owner, :release)
    Process.demonitor(lease.monitor, [:flush])
    result
  catch
    :exit, _reason -> released_owner(lease)
  end

  defp attach(owner) do
    :ok = Owner.attach(owner, self())
    {:ok, %__MODULE__{monitor: Process.monitor(owner), owner: owner}}
  catch
    :exit, _reason -> {:error, Failure.storage_unavailable()}
  end

  defp released_owner(lease) do
    lease.owner
    |> Process.alive?()
    |> released_owner_result(lease)
  end

  defp released_owner_result(false, lease) do
    Process.demonitor(lease.monitor, [:flush])
    :ok
  end

  defp released_owner_result(true, _lease) do
    {:error, Failure.storage_unavailable()}
  end
end
