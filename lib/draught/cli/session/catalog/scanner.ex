defmodule Draught.CLI.Session.Catalog.Scanner do
  @moduledoc """
  Scans one workspace session directory without creating state or replaying journals.

  Directory entry count and every joined identifier are validated before any
  per-session file is inspected.
  """

  alias Draught.CLI.Session.Catalog.Entry
  alias Draught.CLI.Session.Catalog.Scanner.Artifact
  alias Draught.CLI.Session.Catalog.Scanner.Directory
  alias Draught.CLI.Session.Catalog.Scanner.DirectoryListing
  alias Draught.CLI.Session.Catalog.Scanner.SessionEntry
  alias Draught.CLI.Session.Failure
  alias Draught.CLI.Session.Store.Paths
  alias Draught.CLI.Session.Store.Scope

  @doc "Returns deterministic bounded catalog entries from one trusted scope."
  @spec list(Scope.t()) :: {:ok, [Entry.t()]} | {:error, term()}
  def list(%Scope{} = scope) do
    case Directory.validate(scope) do
      :missing -> {:ok, []}
      :ok -> list_directory(scope)
      {:error, _error} = result -> result
    end
  end

  @doc "Fetches one immutable identifier independently of the catalog entry count."
  @spec fetch(Scope.t(), String.t()) :: {:ok, Entry.t()} | {:error, term()}
  def fetch(%Scope{} = scope, identifier) do
    with :ok <- existing_directory(scope),
         {:ok, paths} <- Paths.from_scope(scope, identifier) do
      SessionEntry.fetch(paths, identifier)
    end
  end

  defp list_directory(scope) do
    case DirectoryListing.list(scope.sessions) do
      {:ok, names} -> entries(scope, names)
      {:error, _error} = result -> result
    end
  end

  defp existing_directory(scope) do
    case Directory.validate(scope) do
      :ok -> :ok
      :missing -> {:error, :not_found}
      {:error, _error} = result -> result
    end
  end

  defp entries(scope, names) do
    result =
      Enum.reduce_while(names, {:ok, []}, fn name, {:ok, records} ->
        reduce_entry(scope, name, records)
      end)

    reverse_entries(result)
  end

  defp reduce_entry(scope, name, records) do
    case Paths.from_scope(scope, name) do
      {:ok, paths} ->
        entry = SessionEntry.load(paths, name)
        {:cont, {:ok, [entry | records]}}

      {:error, _error} ->
        artifact_result(Artifact.validate(scope.sessions, name), records)
    end
  end

  defp artifact_result(:ok, records) do
    {:cont, {:ok, records}}
  end

  defp artifact_result({:error, _reason}, _records) do
    {:halt, {:error, Failure.storage_unsafe()}}
  end

  defp reverse_entries({:ok, entries}) do
    {:ok, Enum.reverse(entries)}
  end

  defp reverse_entries({:error, _error} = result) do
    result
  end
end
