defmodule Draught.CLI.Session.Store do
  @moduledoc false

  alias Draught.CLI.Session.Store.Handle
  alias Draught.CLI.Session.Store.Lease
  alias Draught.CLI.Session.Store.Local
  alias Draught.CLI.Session.Store.Paths
  alias Draught.Validation.Error

  @type error :: Draught.Error.Normalized.t() | Error.t()
  @type mode :: :create | :resume

  @doc "Opens a process-owned create or resume session while retaining its exclusive lease."
  @spec open(term(), term(), term(), term()) :: {:ok, Handle.t()} | {:error, error()}
  def open(mode, workspace, identifier, environment) do
    with :ok <- validate_mode(mode),
         {:ok, paths} <- Paths.new(workspace, identifier, environment),
         :ok <- Local.prepare(paths),
         {:ok, lease} <- Lease.acquire(paths) do
      open_leased(mode, paths, lease)
    end
  end

  @doc "Opens a named create transaction and recovers marker-only interrupted initialization."
  @spec initialize(term(), term(), term()) :: {:ok, Handle.t()} | {:error, error()}
  def initialize(workspace, identifier, environment) do
    with {:ok, paths} <- Paths.new(workspace, identifier, environment),
         :ok <- Local.prepare(paths),
         {:ok, lease} <- Lease.acquire(paths) do
      open_leased(:initialize, paths, lease)
    end
  end

  @doc "Closes a session store handle and releases its exclusive lease."
  @spec close(Handle.t()) :: :ok | {:error, Draught.Error.Normalized.t()}
  def close(%Handle{lease: lease}) do
    Lease.release(lease)
  end

  @doc "Aborts only an uninitialized create handle while retaining its lease."
  @spec abort_create(Handle.t()) :: :ok | {:error, Draught.Error.Normalized.t()}
  def abort_create(%Handle{mode: :create, paths: paths}) do
    Local.abort(paths)
  end

  defp open_leased(mode, paths, lease) do
    case apply_mode(mode, paths) do
      :ok -> {:ok, %Handle{lease: lease, mode: handle_mode(mode), paths: paths}}
      {:error, error} -> release_failed_open(Lease.release(lease), error)
    end
  end

  defp validate_mode(mode) when mode in [:create, :resume] do
    :ok
  end

  defp validate_mode(_mode) do
    Error.single([:mode], :invalid_value, "must be create or resume")
  end

  defp apply_mode(:create, paths) do
    Local.create(paths)
  end

  defp apply_mode(:resume, paths) do
    Local.validate(paths)
  end

  defp apply_mode(:initialize, paths) do
    Local.initialize(paths)
  end

  defp handle_mode(:initialize) do
    :create
  end

  defp handle_mode(mode) do
    mode
  end

  defp release_failed_open(:ok, error) do
    {:error, error}
  end

  defp release_failed_open({:error, release_error}, _error) do
    {:error, release_error}
  end
end
