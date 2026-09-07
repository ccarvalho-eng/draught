defmodule Draught.CLI.Task.Named.Lease do
  @moduledoc false

  alias Draught.CLI.Session.Store

  @doc "Opens a named store while categorizing its failures."
  @spec open(Store.mode(), String.t(), String.t(), map()) ::
          {:ok, Store.Handle.t()} | {:error, :session, Draught.CLI.Task.error()}
  def open(mode, workspace, identifier, environment) do
    case open_store(mode, workspace, identifier, environment) do
      {:ok, store} -> {:ok, store}
      {:error, error} -> {:error, :session, error}
    end
  end

  defp open_store(:create, workspace, identifier, environment) do
    Store.initialize(workspace, identifier, environment)
  end

  defp open_store(:resume, workspace, identifier, environment) do
    Store.open(:resume, workspace, identifier, environment)
  end

  @doc "Runs an operation and definitively releases its store lease."
  @spec run_opened(Store.Handle.t(), (-> Draught.CLI.Task.result())) :: Draught.CLI.Task.result()
  def run_opened(store, operation) do
    pair =
      try do
        result = operation.()
        {result, Store.close(store)}
      after
        release_if_alive(store)
      end

    close_result(pair)
  end

  @doc "Removes only an uninitialized create store."
  @spec abort(Store.Handle.t(), Draught.CLI.Task.error()) ::
          {:error, :session, Draught.CLI.Task.error()}
  def abort(store, error) do
    case Store.abort_create(store) do
      :ok -> {:error, :session, error}
      {:error, abort_error} -> {:error, :session, abort_error}
    end
  end

  defp release_if_alive(store) do
    store.lease.owner
    |> Process.alive?()
    |> release_result(store)
  end

  defp release_result(true, store) do
    Store.close(store)
  end

  defp release_result(false, _store) do
    :ok
  end

  defp close_result({result, :ok}) do
    result
  end

  defp close_result({_result, {:error, error}}) do
    {:error, :session, error}
  end
end
