defmodule Draught.Conversation.Interchange.Bundle.Decoder.Reconstructor do
  @moduledoc """
  Reconstructs a canonical document from a bundle manifest and attachments.

  Manifest descriptors may not contain inline bytes, and every archived
  attachment must match a descriptor before validated content is attached.
  """

  alias Draught.Conversation.Attachment
  alias Draught.Conversation.Document
  alias Draught.Conversation.Document.Collection
  alias Draught.Conversation.Interchange.Bundle.Entry
  alias Draught.Conversation.Interchange.Text
  alias Draught.Validation.Error

  @doc "Decodes the strict manifest and validates its archive relationships."
  @spec decode_manifest([Entry.t()], binary()) :: Error.result(Document.t())
  def decode_manifest(entries, manifest) do
    with {:ok, document} <- Text.decode_artifact(manifest),
         :ok <- validate_descriptor_content(document.attachments),
         :ok <- validate_archive_relationship(entries, document.attachments) do
      {:ok, document}
    end
  end

  @doc "Adds validated extracted bytes to their canonical attachment descriptors."
  @spec attach(Document.t(), %{String.t() => binary()}) :: Error.result(Document.t())
  def attach(document, extracted) do
    case rebuild_attachments(document.attachments, extracted) do
      {:ok, attachments} -> {:ok, %{document | attachments: attachments}}
      {:error, %Error{}} = result -> result
    end
  end

  defp validate_descriptor_content(attachments) do
    attachments
    |> Enum.all?(&is_nil(&1.content))
    |> descriptor_content_result()
  end

  defp descriptor_content_result(true) do
    :ok
  end

  defp descriptor_content_result(false) do
    Error.single(
      [:attachments],
      :invalid_relationship,
      "manifest attachments must not contain inline content"
    )
  end

  defp validate_archive_relationship(entries, attachments) do
    archive_names =
      entries
      |> Enum.filter(&(&1.kind == :attachment))
      |> MapSet.new(& &1.name)

    descriptor_names = MapSet.new(attachments, & &1.name)

    archive_names
    |> MapSet.subset?(descriptor_names)
    |> relationship_result()
  end

  defp relationship_result(true) do
    :ok
  end

  defp relationship_result(false) do
    Error.single(
      [:attachments],
      :invalid_relationship,
      "archive attachments must have matching manifest descriptors"
    )
  end

  defp rebuild_attachments(attachments, extracted) do
    attachments
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, &rebuild_attachment(&1, &2, extracted))
    |> reverse_attachments()
  end

  defp rebuild_attachment({attachment, index}, {:ok, rebuilt}, extracted) do
    path = "attachments/" <> attachment.name

    case Map.fetch(extracted, path) do
      {:ok, content} -> rebuild_with_content(attachment, content, rebuilt, index)
      :error -> {:cont, {:ok, [attachment | rebuilt]}}
    end
  end

  defp rebuild_with_content(attachment, content, rebuilt, index) do
    attributes =
      attachment
      |> Map.from_struct()
      |> Map.put(:content, content)

    case Attachment.new(attributes) do
      {:ok, retained} ->
        {:cont, {:ok, [retained | rebuilt]}}

      {:error, %Error{} = error} ->
        {:halt, {:error, Collection.prefix_error(error, [:attachments, index])}}
    end
  end

  defp reverse_attachments({:ok, attachments}) do
    {:ok, Enum.reverse(attachments)}
  end

  defp reverse_attachments({:error, %Error{}} = result) do
    result
  end
end
