defmodule Draught.Conversation.Document.Attachments do
  @moduledoc """
  Normalizes the attachment collection of a conversation document.

  The collection is bounded by count and declared bytes. Names must also be
  unique under case-insensitive comparison for portable archive extraction.
  """

  alias Draught.Conversation.Attachment
  alias Draught.Conversation.Document.Collection
  alias Draught.Validation.Error

  @maximum_attachments 64
  @maximum_total_bytes 67_108_864

  @doc "Normalizes and validates the bounded attachment collection."
  @spec normalize(term()) :: Error.result([Attachment.t()])
  def normalize(attachments) when is_list(attachments) do
    with :ok <- validate_count(attachments),
         {:ok, normalized} <- normalize_all(attachments),
         :ok <- validate_unique_names(normalized) do
      {:ok, normalized}
    end
  end

  def normalize(_attachments) do
    Error.single([:attachments], :invalid_type, "must be a list")
  end

  defp validate_count(attachments) do
    attachments
    |> length()
    |> count_result()
  end

  defp count_result(count) when count <= @maximum_attachments do
    :ok
  end

  defp count_result(_count) do
    Error.single(
      [:attachments],
      :too_large,
      "must not contain more than #{@maximum_attachments} attachments"
    )
  end

  defp normalize_all(attachments) do
    attachments
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, [], 0}, &normalize_attachment/2)
    |> Collection.finish()
  end

  defp normalize_attachment({attachment, index}, {:ok, normalized, total_bytes}) do
    case canonical_attachment(attachment) do
      {:ok, canonical} ->
        accumulate(canonical, normalized, total_bytes)

      {:error, %Error{} = error} ->
        {:halt, {:error, Collection.prefix_error(error, [:attachments, index])}}
    end
  end

  defp accumulate(attachment, normalized, total_bytes) do
    next_total = total_bytes + attachment.byte_size

    case total_size_result(next_total) do
      :ok -> {:cont, {:ok, [attachment | normalized], next_total}}
      {:error, %Error{}} = result -> {:halt, result}
    end
  end

  defp canonical_attachment(%Attachment{} = attachment) do
    attachment
    |> Map.from_struct()
    |> Attachment.new()
  end

  defp canonical_attachment(attachment) when is_map(attachment) or is_list(attachment) do
    Attachment.new(attachment)
  end

  defp canonical_attachment(_attachment) do
    Error.single([], :invalid_type, "must be an attachment or attachment attributes")
  end

  defp validate_unique_names(attachments) do
    names = Enum.map(attachments, &String.downcase(&1.name))

    names
    |> MapSet.new()
    |> MapSet.size()
    |> unique_names_result(length(names))
  end

  defp unique_names_result(count, count) do
    :ok
  end

  defp unique_names_result(_unique_count, _count) do
    Error.single(
      [:attachments],
      :invalid_relationship,
      "must have unique portable names regardless of case"
    )
  end

  defp total_size_result(total) when total <= @maximum_total_bytes do
    :ok
  end

  defp total_size_result(_total) do
    Error.single(
      [:attachments],
      :too_large,
      "declared content must not exceed #{@maximum_total_bytes} bytes in total"
    )
  end
end
