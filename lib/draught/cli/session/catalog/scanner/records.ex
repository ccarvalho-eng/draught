defmodule Draught.CLI.Session.Catalog.Scanner.Records do
  @moduledoc """
  Loads validated bounded records for one available session catalog entry.

  This projection reads only small sidecar records and never replays the
  authoritative conversation journal.
  """

  alias Draught.CLI.Session.Binding
  alias Draught.CLI.Session.Catalog.Entry
  alias Draught.CLI.Session.Catalog.Metadata
  alias Draught.CLI.Session.Catalog.Preview
  alias Draught.CLI.Session.Store.Paths

  @doc "Projects binding, lifecycle metadata, and an optional preview into one entry."
  @spec load(Paths.t(), String.t()) :: {:ok, Entry.t()} | {:error, term()}
  def load(%Paths{} = paths, identifier) do
    with {:ok, binding} <- Binding.Local.read(paths),
         {:ok, metadata} <- Metadata.Local.read(paths),
         {:ok, preview} <- Preview.Local.read(paths) do
      Entry.available(identifier, binding, metadata, preview_text(preview))
    end
  end

  defp preview_text(nil) do
    nil
  end

  defp preview_text(%Preview{text: text}) do
    text
  end
end
