defmodule Draught.Conversation.Document.Builder do
  @moduledoc false

  alias Draught.Conversation.Document.Attachments
  alias Draught.Conversation.Document.Messages
  alias Draught.Conversation.Document.Usage
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.JSON

  @doc "Builds normalized document fields for the supported schema version."
  @spec build(term(), pos_integer()) :: Error.result(map())
  def build(attributes, schema_version) do
    with {:ok, normalized} <- normalize_attributes(attributes),
         {:ok, raw_messages} <- Attributes.fetch_required(normalized, :messages) do
      build_normalized(normalized, raw_messages, schema_version)
    end
  end

  defp normalize_attributes(attributes) do
    Attributes.normalize(attributes, [
      :schema_version,
      :messages,
      :usage,
      :metadata,
      :attachments
    ])
  end

  defp build_normalized(attributes, raw_messages, schema_version) do
    with {:ok, core} <- core_fields(attributes, raw_messages, schema_version),
         {:ok, optional} <- optional_fields(attributes) do
      {:ok, Map.merge(core, optional)}
    end
  end

  defp core_fields(attributes, raw_messages, schema_version) do
    raw_version = Map.get(attributes, :schema_version, schema_version)

    with {:ok, version} <- version(raw_version, schema_version),
         {:ok, messages} <- Messages.normalize(raw_messages) do
      {:ok, %{schema_version: version, messages: messages}}
    end
  end

  defp optional_fields(attributes) do
    with {:ok, usage} <-
           attributes
           |> Map.get(:usage)
           |> Usage.normalize(),
         {:ok, metadata} <-
           attributes
           |> Map.get(:metadata, %{})
           |> metadata(),
         {:ok, attachments} <-
           attributes
           |> Map.get(:attachments, [])
           |> Attachments.normalize() do
      {:ok, %{usage: usage, metadata: metadata, attachments: attachments}}
    end
  end

  defp version(schema_version, schema_version) do
    {:ok, schema_version}
  end

  defp version(_version, _schema_version) do
    Error.single([:schema_version], :invalid_value, "is not a supported document version")
  end

  defp metadata(metadata) do
    case JSON.validate_object(metadata, [:metadata]) do
      :ok -> {:ok, metadata}
      {:error, %Error{}} = result -> result
    end
  end
end
