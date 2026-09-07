defmodule Draught.Conversation.Interchange.Bundle.Decoder do
  @moduledoc """
  Coordinates bounded validation and decoding of conversation bundles.

  ZIP structures and entry metadata are validated before any selective
  extraction, then extracted content is reconciled with the manifest.
  """

  alias Draught.Conversation.Interchange.Bundle.Decoder.CentralDirectory
  alias Draught.Conversation.Interchange.Bundle.Decoder.EndOfCentralDirectory
  alias Draught.Conversation.Interchange.Bundle.Decoder.Extractor
  alias Draught.Conversation.Interchange.Bundle.Decoder.Reconstructor
  alias Draught.Conversation.Interchange.Bundle.Decoder.Table
  alias Draught.Validation.Error

  @maximum_entries 65

  @doc "Validates and decodes one in-memory archive."
  @spec decode(term(), pos_integer()) :: Error.result(Draught.Conversation.Document.t())
  def decode(archive, maximum_bytes) when is_binary(archive) do
    with :ok <- validate_size(archive, maximum_bytes),
         {:ok, entries} <- validate_archive(archive),
         {:ok, document} <- decode_manifest(archive, entries) do
      decode_attachments(archive, entries, document)
    end
  end

  def decode(_archive, _maximum_bytes) do
    Error.single([], :invalid_type, "must be bundle bytes")
  end

  defp validate_size(archive, maximum_bytes) when byte_size(archive) <= maximum_bytes do
    :ok
  end

  defp validate_size(_archive, maximum_bytes) do
    Error.single([], :too_large, "bundle must not exceed #{maximum_bytes} bytes")
  end

  defp validate_archive(archive) do
    with {:ok, directory} <- EndOfCentralDirectory.validate(archive, @maximum_entries),
         :ok <- CentralDirectory.validate(archive, directory) do
      Table.read(archive, directory.entries)
    end
  end

  defp decode_manifest(archive, entries) do
    with {:ok, manifest} <- extract_manifest(archive, entries) do
      Reconstructor.decode_manifest(entries, manifest)
    end
  end

  defp decode_attachments(archive, entries, document) do
    with {:ok, extracted} <- Extractor.extract(archive, attachment_entries(entries)) do
      Reconstructor.attach(document, extracted)
    end
  end

  defp extract_manifest(archive, entries) do
    manifest = Enum.find(entries, &(&1.kind == :manifest))

    case Extractor.extract(archive, [manifest]) do
      {:ok, %{"conversation.lmml" => content}} -> {:ok, content}
      {:error, %Error{}} = result -> result
    end
  end

  defp attachment_entries(entries) do
    Enum.filter(entries, &(&1.kind == :attachment))
  end
end
