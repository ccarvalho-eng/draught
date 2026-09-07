defmodule Draught.CLI.Session.Catalog.Metadata.Local do
  @moduledoc """
  Reads and atomically updates bounded owner-only session metadata records.

  A missing record is interpreted as legacy active metadata. Other unsafe,
  oversized, or malformed records fail closed.
  """

  alias Draught.CLI.Session.Catalog.Metadata
  alias Draught.CLI.Session.Failure
  alias Draught.CLI.Session.Store.AtomicFile
  alias Draught.CLI.Session.Store.Paths
  alias Draught.Session.Journal.Local.SafeFile

  @maximum_bytes 4_096

  @doc "Reads metadata or returns the legacy active representation when absent."
  @spec read(Paths.t()) :: {:ok, Metadata.t()} | {:error, Draught.Error.Normalized.t()}
  def read(%Paths{} = paths) do
    identifier = identifier(paths)

    case SafeFile.read(paths.metadata, @maximum_bytes) do
      {:ok, encoded} -> decode(encoded, identifier)
      {:error, :missing} -> {:ok, Metadata.legacy(identifier)}
      {:error, _reason} -> {:error, Failure.invalid_metadata()}
    end
  end

  @doc "Creates or replaces metadata while the caller retains the session lease."
  @spec put(Paths.t(), Metadata.t()) :: :ok | {:error, Draught.Error.Normalized.t()}
  def put(%Paths{} = paths, %Metadata{} = metadata) do
    with :ok <- matching_identifier(metadata, paths),
         {:ok, encoded} <- Metadata.encode(metadata) do
      publish(paths.metadata, encoded, publication(paths.metadata))
    end
  end

  @doc "Requires the session metadata to permit resume."
  @spec require_active(Paths.t()) :: :ok | {:error, Draught.Error.Normalized.t()}
  def require_active(%Paths{} = paths) do
    case read(paths) do
      {:ok, %Metadata{archived_at: nil}} -> :ok
      {:ok, %Metadata{archived_at: %DateTime{}}} -> {:error, Failure.archived()}
      {:error, _error} = result -> result
    end
  end

  defp publication(path) do
    case File.lstat(path) do
      {:error, :enoent} -> :create
      {:ok, %File.Stat{}} -> :replace
      {:error, _reason} -> :replace
    end
  end

  defp publish(path, encoded, publication) do
    case AtomicFile.write(path, encoded, publication, "metadata") do
      :ok -> :ok
      {:error, :io} -> {:error, Failure.storage_unavailable()}
      {:error, :publication_unknown} -> {:error, Failure.publication_unknown()}
    end
  end

  defp identifier(paths) do
    Path.basename(paths.session)
  end

  defp matching_identifier(%Metadata{id: identifier}, paths) do
    matching_identifier_result(identifier == identifier(paths))
  end

  defp matching_identifier_result(true) do
    :ok
  end

  defp matching_identifier_result(false) do
    {:error, Failure.invalid_metadata()}
  end

  defp decode(encoded, identifier) do
    case Metadata.decode(encoded) do
      {:ok, %Metadata{id: ^identifier} = metadata} -> {:ok, metadata}
      {:ok, %Metadata{}} -> {:error, Failure.invalid_metadata()}
      {:error, _error} = result -> result
    end
  end
end
