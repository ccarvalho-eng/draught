defmodule Draught.CLI.Session.Catalog.Mutation.Transaction do
  @moduledoc """
  Owns the per-session lease lifecycle for catalog metadata changes.

  The operation runs only after the durable session marker is validated. Lease
  release is attempted after normal completion and again after exceptional exits
  when the lease owner remains alive.
  """

  alias Draught.CLI.Session.Store

  @type operation(result) :: (Store.Paths.t() -> result)

  @doc "Runs one catalog operation under the existing session lease."
  @spec run(String.t(), String.t(), map(), operation(result)) ::
          result | {:error, term()}
        when result: term()
  def run(workspace, identifier, environment, operation) when is_function(operation, 1) do
    with {:ok, store} <- Store.open(:manage, workspace, identifier, environment) do
      transact(store, operation)
    end
  end

  defp transact(store, operation) do
    pair =
      try do
        {operation.(store.paths), Store.close(store)}
      after
        store.lease.owner
        |> Process.alive?()
        |> release_if_alive(store)
      end

    close_result(pair)
  end

  defp release_if_alive(true, store) do
    Store.close(store)
  end

  defp release_if_alive(false, _store) do
    :ok
  end

  defp close_result({result, :ok}) do
    result
  end

  defp close_result({_result, {:error, error}}) do
    {:error, error}
  end
end
