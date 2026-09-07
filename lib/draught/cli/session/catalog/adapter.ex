defmodule Draught.CLI.Session.Catalog.Adapter do
  @moduledoc """
  Defines session discovery and metadata mutation effects used by the CLI shell.
  """

  alias Draught.CLI.Session.Catalog.Entry

  @type configuration :: term()
  @type result(value) :: {:ok, value} | {:error, term()}

  @doc "Lists bounded session summaries for one workspace."
  @callback list(String.t(), map(), configuration()) :: result([Entry.t()])

  @doc "Fetches one session by immutable identifier without scanning the catalog."
  @callback fetch(String.t(), String.t(), map(), configuration()) :: result(Entry.t())

  @doc "Renames one immutable session identifier through display metadata."
  @callback rename(String.t(), String.t(), String.t(), map(), configuration()) ::
              result(Entry.t())

  @doc "Soft-archives one session without moving or deleting its journal."
  @callback archive(String.t(), String.t(), map(), configuration()) :: result(Entry.t())

  @doc "Restores one archived session to the active catalog."
  @callback restore(String.t(), String.t(), map(), configuration()) :: result(Entry.t())
end
