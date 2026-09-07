defmodule Draught.CLI.Session.Catalog.Mutation do
  @moduledoc """
  Serializes reversible session metadata changes under the session's existing lease.

  Management opens validate the durable marker without applying active-session
  policy, allowing archived records to be restored safely.
  """

  alias Draught.CLI.Session.Binding
  alias Draught.CLI.Session.Catalog.Entry
  alias Draught.CLI.Session.Catalog.Metadata
  alias Draught.CLI.Session.Catalog.Metadata.Local
  alias Draught.CLI.Session.Catalog.Mutation.Transaction

  @type action :: {:rename, String.t()} | :archive | :restore

  @doc "Applies one metadata action while holding the per-session lease."
  @spec run(String.t(), String.t(), map(), action(), term()) ::
          {:ok, Entry.t()} | {:error, term()}
  def run(workspace, identifier, environment, action, configuration) do
    Transaction.run(workspace, identifier, environment, fn paths ->
      change(paths, identifier, action, configuration)
    end)
  end

  defp change(paths, identifier, action, configuration) do
    with {:ok, binding} <- Binding.Local.read(paths),
         {:ok, metadata} <- Local.read(paths),
         {:ok, _current} <- Entry.available(identifier, binding, metadata),
         {:ok, updated} <- update(metadata, action, configuration),
         {:ok, entry} <- Entry.available(identifier, binding, updated),
         :ok <- Local.put(paths, updated) do
      {:ok, entry}
    end
  end

  defp update(metadata, {:rename, label}, _configuration) do
    Metadata.rename(metadata, label)
  end

  defp update(
         %Metadata{archived_at: %DateTime{}} = metadata,
         :archive,
         _configuration
       ) do
    {:ok, metadata}
  end

  defp update(metadata, :archive, configuration) do
    {:ok, Metadata.archive(metadata, now(configuration))}
  end

  defp update(metadata, :restore, _configuration) do
    {:ok, Metadata.restore(metadata)}
  end

  defp now(configuration) when is_list(configuration) do
    clock = Keyword.get(configuration, :clock, &DateTime.utc_now/0)
    clock.()
  end

  defp now(_configuration) do
    DateTime.utc_now()
  end
end
