defmodule Draught.Conversation.Interchange.Text.Encoder do
  @moduledoc false

  alias Draught.Conversation.Interchange.Text.Encoder.Document
  alias Draught.Conversation.Interchange.Text.Encoder.Narrative
  alias Draught.Conversation.Interchange.Text.JSON
  alias Draught.Conversation.Interchange.Text.Options
  alias Draught.Validation.Error

  @format "draught.conversation"
  @format_version 1

  @doc "Validates and encodes one document within the supplied byte limit."
  @spec encode(term(), term(), pos_integer()) :: Error.result(String.t())
  def encode(document, options, maximum_bytes) do
    with {:ok, export_options} <- Options.new(options),
         {:ok, canonical} <- canonical_document(document),
         {:ok, extension} <- encode_extension(canonical, export_options),
         artifact <- render(extension, Narrative.render(canonical)),
         :ok <- validate_size(artifact, maximum_bytes) do
      {:ok, artifact}
    end
  end

  defp canonical_document(%Draught.Conversation.Document{} = document) do
    document
    |> Map.from_struct()
    |> Draught.Conversation.Document.new()
  end

  defp canonical_document(document) do
    Draught.Conversation.Document.new(document)
  end

  defp encode_extension(document, options) do
    extension =
      JSON.object([
        {"format", @format},
        {"format_version", @format_version},
        {"document", Document.encode(document, options)}
      ])

    case Jason.encode(extension, pretty: true) do
      {:ok, encoded} -> {:ok, encoded}
      {:error, _reason} -> Error.single([], :invalid_format, "could not encode the document")
    end
  end

  defp render(extension, narrative) do
    "@@@draught.json\n" <> extension <> "\n@@@\n\n" <> narrative
  end

  defp validate_size(artifact, maximum_bytes) when byte_size(artifact) <= maximum_bytes do
    :ok
  end

  defp validate_size(_artifact, maximum_bytes) do
    Error.single([], :too_large, "encoded artifact must not exceed #{maximum_bytes} bytes")
  end
end
