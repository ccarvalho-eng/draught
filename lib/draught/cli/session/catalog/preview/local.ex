defmodule Draught.CLI.Session.Catalog.Preview.Local do
  @moduledoc """
  Reads and atomically replaces bounded owner-only session preview records.

  A missing preview is valid for legacy sessions and completed turns whose
  derived preview could not be published.
  """

  alias Draught.CLI.Session.Catalog.Preview
  alias Draught.CLI.Session.Failure
  alias Draught.CLI.Session.Store.AtomicFile
  alias Draught.CLI.Session.Store.Paths
  alias Draught.Session.Journal.Local.SafeFile

  @maximum_bytes 1_024

  @doc "Reads the latest preview or returns nil when the derived record is absent."
  @spec read(Paths.t()) :: {:ok, Preview.t() | nil} | {:error, Draught.Error.Normalized.t()}
  def read(%Paths{} = paths) do
    case SafeFile.read(paths.preview, @maximum_bytes) do
      {:ok, encoded} -> decode(encoded, identifier(paths))
      {:error, :missing} -> {:ok, nil}
      {:error, _reason} -> {:error, Failure.invalid_preview()}
    end
  end

  @doc "Creates or replaces a preview while the caller retains the session lease."
  @spec put(Paths.t(), Preview.t()) :: :ok | {:error, Draught.Error.Normalized.t()}
  def put(%Paths{} = paths, %Preview{} = preview) do
    with :ok <- matching_identifier(preview, paths),
         {:ok, encoded} <- Preview.encode(preview) do
      publish(paths.preview, encoded, publication(paths.preview))
    end
  end

  defp decode(encoded, identifier) do
    case Preview.decode(encoded) do
      {:ok, %Preview{id: ^identifier} = preview} -> {:ok, preview}
      _result -> {:error, Failure.invalid_preview()}
    end
  end

  defp identifier(paths) do
    Path.basename(paths.session)
  end

  defp matching_identifier(%Preview{id: identifier}, paths) do
    matching_identifier_result(identifier == identifier(paths))
  end

  defp matching_identifier_result(true) do
    :ok
  end

  defp matching_identifier_result(false) do
    {:error, Failure.invalid_preview()}
  end

  defp publication(path) do
    case File.lstat(path) do
      {:error, :enoent} -> :create
      _result -> :replace
    end
  end

  defp publish(path, encoded, publication) do
    case AtomicFile.write(path, encoded, publication, "preview") do
      :ok -> :ok
      {:error, :io} -> {:error, Failure.storage_unavailable()}
      {:error, :publication_unknown} -> {:error, Failure.publication_unknown()}
    end
  end
end
