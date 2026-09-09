defmodule Draught.CLI.Session.Catalog.Scanner.SessionEntry do
  @moduledoc """
  Projects one validated session directory into a safe catalog entry.

  Catalog scans do not expose corrupt record contents. Any invalid store,
  binding, or metadata record becomes an unavailable entry containing only its
  already-validated immutable identifier.
  """

  alias Draught.CLI.Session.Catalog.Entry
  alias Draught.CLI.Session.Catalog.Scanner.Records
  alias Draught.CLI.Session.Failure
  alias Draught.CLI.Session.Store.Local
  alias Draught.CLI.Session.Store.Paths

  @doc "Loads one catalog entry without replaying its journal."
  @spec load(Paths.t(), String.t()) :: Entry.t()
  def load(%Paths{} = paths, identifier) do
    case project(paths, identifier) do
      {:ok, entry} -> entry
      {:error, _reason} -> Entry.unavailable(identifier)
    end
  end

  @doc "Fetches one catalog entry while distinguishing an absent identifier."
  @spec fetch(Paths.t(), String.t()) :: {:ok, Entry.t()} | {:error, term()}
  def fetch(%Paths{} = paths, identifier) do
    case File.lstat(paths.session) do
      {:ok, %File.Stat{}} -> {:ok, load(paths, identifier)}
      {:error, :enoent} -> {:error, :not_found}
      {:error, _reason} -> {:error, Failure.storage_unavailable()}
    end
  end

  defp project(paths, identifier) do
    case Local.validate(paths) do
      :ok -> Records.load(paths, identifier)
      {:error, _reason} = error -> error
    end
  end
end
