defmodule Draught.CLI.Session.Catalog do
  @moduledoc """
  Provides the CLI-facing context for bounded session discovery and metadata changes.

  Callers supply an explicit adapter so terminal controllers remain independent
  of filesystem storage details.
  """

  alias Draught.CLI.Session.Catalog.Entry

  @type adapter :: {module(), term()}
  @type result(value) :: {:ok, value} | {:error, term()}

  @doc "Lists sessions in one workspace through the configured adapter."
  @spec list(adapter(), String.t(), map()) :: result([Entry.t()])
  def list({adapter, configuration}, workspace, environment) do
    adapter.list(workspace, environment, configuration)
  end

  @doc "Fetches one session by immutable identifier without listing its workspace."
  @spec fetch(adapter(), String.t(), String.t(), map()) :: result(Entry.t())
  def fetch({adapter, configuration}, workspace, identifier, environment) do
    adapter.fetch(workspace, identifier, environment, configuration)
  end

  @doc "Renames one session without changing its immutable identifier."
  @spec rename(adapter(), String.t(), String.t(), String.t(), map()) :: result(Entry.t())
  def rename({adapter, configuration}, workspace, identifier, label, environment) do
    adapter.rename(workspace, identifier, label, environment, configuration)
  end

  @doc "Soft-archives one session."
  @spec archive(adapter(), String.t(), String.t(), map()) :: result(Entry.t())
  def archive({adapter, configuration}, workspace, identifier, environment) do
    adapter.archive(workspace, identifier, environment, configuration)
  end

  @doc "Restores one archived session."
  @spec restore(adapter(), String.t(), String.t(), map()) :: result(Entry.t())
  def restore({adapter, configuration}, workspace, identifier, environment) do
    adapter.restore(workspace, identifier, environment, configuration)
  end

  @doc "Resolves one available catalog entry by exact immutable ID or unique label."
  @spec resolve([Entry.t()], String.t(), :active | :any | :archived) ::
          {:ok, Entry.t()} | {:error, :ambiguous | :not_found | :unavailable}
  def resolve(entries, reference, archive) when is_binary(reference) do
    candidates = Enum.filter(entries, &candidate?(&1, archive))

    case Enum.find(candidates, &(&1.id == reference)) do
      %Entry{} = entry -> {:ok, entry}
      nil -> resolve_label(candidates, entries, reference)
    end
  end

  defp candidate?(%Entry{availability: :available, archive: :active}, :active) do
    true
  end

  defp candidate?(%Entry{availability: :available}, :any) do
    true
  end

  defp candidate?(
         %Entry{availability: :available, archive: {:archived, %DateTime{}}},
         :archived
       ) do
    true
  end

  defp candidate?(%Entry{}, _archive) do
    false
  end

  defp resolve_label(candidates, entries, reference) do
    case Enum.filter(candidates, &(&1.label == reference)) do
      [%Entry{} = entry] -> {:ok, entry}
      [] -> unavailable_or_missing(entries, reference)
      [_first, _second | _rest] -> {:error, :ambiguous}
    end
  end

  defp unavailable_or_missing(entries, reference) do
    case Enum.find(entries, &(&1.id == reference and &1.availability == :unavailable)) do
      %Entry{} -> {:error, :unavailable}
      nil -> {:error, :not_found}
    end
  end
end
