defmodule Draught.CLI.Interactive.Session.Lookup do
  @moduledoc """
  Resolves session references without requiring a complete catalog scan for IDs.

  Exact immutable identifiers use direct bounded lookup. Human-readable names
  require the bounded workspace catalog and retain exact-ID precedence.
  """

  alias Draught.CLI.Dependencies
  alias Draught.CLI.Interactive.State
  alias Draught.CLI.Session.Catalog
  alias Draught.Session.Identifier

  @type archive :: :active | :any | :archived

  @doc "Lists the bounded workspace catalog."
  @spec list(State.t(), Dependencies.t()) :: {:ok, [Catalog.Entry.t()]} | {:error, term()}
  def list(state, dependencies) do
    Catalog.list(dependencies.catalog, state.workspace, environment(dependencies))
  end

  @doc "Resolves an immutable ID directly or a unique name through the catalog."
  @spec resolve(String.t(), archive(), State.t(), Dependencies.t()) ::
          {:ok, Catalog.Entry.t()} | {:error, term()}
  def resolve(reference, archive, state, dependencies) do
    case Identifier.new(reference) do
      {:ok, identifier} -> resolve_identifier(identifier, archive, state, dependencies)
      {:error, _error} -> resolve_name(reference, archive, state, dependencies)
    end
  end

  @doc "Rejects an immutable identifier already present in the workspace."
  @spec ensure_unused(String.t(), State.t(), Dependencies.t()) ::
          :ok | {:error, term()}
  def ensure_unused(identifier, state, dependencies) do
    case fetch(identifier, state, dependencies) do
      {:ok, _entry} -> {:error, :already_exists}
      {:error, :not_found} -> :ok
      {:error, _reason} = result -> result
    end
  end

  defp resolve_identifier(identifier, archive, state, dependencies) do
    case fetch(identifier, state, dependencies) do
      {:ok, entry} -> Catalog.resolve([entry], identifier, archive)
      {:error, :not_found} -> resolve_name(identifier, archive, state, dependencies)
      {:error, _reason} = result -> result
    end
  end

  defp resolve_name(reference, archive, state, dependencies) do
    with {:ok, entries} <- list(state, dependencies) do
      resolve_catalog_reference(entries, reference, archive)
    end
  end

  defp resolve_catalog_reference(entries, reference, archive) do
    case Catalog.resolve(entries, reference, archive) do
      {:error, :not_found} -> Catalog.resolve_position(entries, reference, archive)
      result -> result
    end
  end

  defp fetch(identifier, state, dependencies) do
    Catalog.fetch(
      dependencies.catalog,
      state.workspace,
      identifier,
      environment(dependencies)
    )
  end

  defp environment(%Dependencies{system: {system, configuration}}) do
    system.environment(configuration)
  end
end
