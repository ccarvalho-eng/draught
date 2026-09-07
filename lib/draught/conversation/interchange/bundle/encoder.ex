defmodule Draught.Conversation.Interchange.Bundle.Encoder do
  @moduledoc false

  alias Draught.Conversation.Document
  alias Draught.Conversation.Interchange.Bundle.Encoder.Archive
  alias Draught.Conversation.Interchange.Text
  alias Draught.Conversation.Interchange.Text.Options
  alias Draught.Validation.Error

  @doc "Validates and encodes one document within the supplied archive limit."
  @spec encode(term(), term(), pos_integer()) :: Error.result(binary())
  def encode(document, options, maximum_bytes) do
    with {:ok, export_options} <- Options.new(options),
         {:ok, canonical} <- canonical_document(document),
         {:ok, manifest} <- encode_manifest(canonical, export_options),
         {:ok, archive} <- Archive.create(manifest, canonical.attachments),
         :ok <- validate_size(archive, maximum_bytes) do
      {:ok, archive}
    end
  end

  defp canonical_document(%Document{} = document) do
    document
    |> Map.from_struct()
    |> Document.new()
  end

  defp canonical_document(document) do
    Document.new(document)
  end

  defp encode_manifest(document, %Options{retain: retain}) do
    manifest_retain =
      retain
      |> MapSet.delete(:attachment_content)
      |> MapSet.put(:attachments)
      |> MapSet.to_list()

    Text.encode(document, retain: manifest_retain)
  end

  defp validate_size(archive, maximum_bytes) when byte_size(archive) <= maximum_bytes do
    :ok
  end

  defp validate_size(_archive, maximum_bytes) do
    Error.single([], :too_large, "bundle must not exceed #{maximum_bytes} bytes")
  end
end
