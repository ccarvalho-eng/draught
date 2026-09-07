defmodule Draught.Conversation.Interchange.Text.Decoder.Extension do
  @moduledoc false

  alias Draught.Conversation.Document
  alias Draught.Conversation.Interchange.Text.Decoder.Attachments
  alias Draught.Conversation.Interchange.Text.Decoder.JSON
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error

  @format "draught.conversation"
  @format_version 1
  @terminator "\n@@@\n"

  @doc "Decodes the authoritative extension from the text following its marker."
  @spec decode(String.t()) :: Error.result(Document.t())
  def decode(rest) do
    with {:ok, encoded} <- split_extension(rest),
         {:ok, value} <- JSON.decode(encoded),
         {:ok, document} <- validate_header(value),
         {:ok, descriptor_document, retained_content} <- Attachments.extract(document),
         {:ok, canonical} <- Document.new(descriptor_document),
         {:ok, attachments} <- Attachments.restore(canonical.attachments, retained_content) do
      {:ok, %{canonical | attachments: attachments}}
    end
  end

  defp split_extension(rest) do
    case :binary.split(rest, @terminator) do
      [encoded, _narrative] when encoded != "" -> {:ok, encoded}
      _parts -> Error.single([], :invalid_format, "has a malformed Draught extension")
    end
  end

  defp validate_header(value) do
    with {:ok, header} <- Attributes.normalize(value, [:format, :format_version, :document]),
         :ok <- validate_format(Map.get(header, :format)),
         :ok <- validate_version(Map.get(header, :format_version)) do
      Attributes.fetch_required(header, :document)
    end
  end

  defp validate_format(@format) do
    :ok
  end

  defp validate_format(_format) do
    Error.single([:format], :invalid_format, "is not a Draught conversation artifact")
  end

  defp validate_version(@format_version) do
    :ok
  end

  defp validate_version(_version) do
    Error.single([:format_version], :unsupported_version, "is not supported")
  end
end
