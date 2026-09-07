defmodule Draught.Conversation.Interchange.Text.Encoder.Document do
  @moduledoc false

  alias Draught.Conversation.Document
  alias Draught.Conversation.Interchange.Text.Encoder.Message
  alias Draught.Conversation.Interchange.Text.JSON
  alias Draught.Conversation.Interchange.Text.Options

  @doc "Converts a canonical document into an ordered JSON value."
  @spec encode(Document.t(), Options.t()) :: Jason.OrderedObject.t()
  def encode(%Document{} = document, options) do
    JSON.object([
      {"schema_version", document.schema_version},
      {"messages", Enum.map(document.messages, &Message.encode(&1, options))},
      {"usage", usage(document.usage)},
      {"metadata", metadata(document.metadata, options)},
      {"attachments", attachments(document.attachments, options)}
    ])
  end

  defp usage(nil) do
    nil
  end

  defp usage(usage) do
    JSON.object([
      {"input_tokens", usage.input_tokens},
      {"output_tokens", usage.output_tokens},
      {"total_tokens", usage.total_tokens},
      {"cached_tokens", usage.cached_tokens},
      {"reasoning_tokens", usage.reasoning_tokens}
    ])
  end

  defp metadata(metadata, options) do
    options
    |> Options.retained?(:metadata)
    |> metadata_value(metadata)
  end

  defp metadata_value(true, metadata) do
    JSON.order(metadata)
  end

  defp metadata_value(false, _metadata) do
    JSON.object([])
  end

  defp attachments(attachments, options) do
    retain_content = Options.retained?(options, :attachment_content)
    retain_descriptors = Options.retained?(options, :attachments)
    retained_attachments(retain_content, retain_descriptors, attachments)
  end

  defp retained_attachments(true, _retain_descriptors, attachments) do
    Enum.map(attachments, &attachment_with_content/1)
  end

  defp retained_attachments(false, true, attachments) do
    Enum.map(attachments, &attachment_descriptor/1)
  end

  defp retained_attachments(false, false, _attachments) do
    []
  end

  defp attachment_with_content(%{content: content} = attachment) when is_binary(content) do
    JSON.object([
      {"name", attachment.name},
      {"media_type", attachment.media_type},
      {"byte_size", attachment.byte_size},
      {"sha256", attachment.sha256},
      {"content_base64", Base.encode64(content)}
    ])
  end

  defp attachment_with_content(attachment) do
    attachment_descriptor(attachment)
  end

  defp attachment_descriptor(attachment) do
    JSON.object([
      {"name", attachment.name},
      {"media_type", attachment.media_type},
      {"byte_size", attachment.byte_size},
      {"sha256", attachment.sha256}
    ])
  end
end
