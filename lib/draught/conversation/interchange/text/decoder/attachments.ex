defmodule Draught.Conversation.Interchange.Text.Decoder.Attachments do
  @moduledoc false

  alias Draught.Conversation.Attachment
  alias Draught.Validation.Error

  @maximum_encoded_bytes div(Attachment.max_bytes() + 2, 3) * 4

  @doc "Separates retained content from descriptors before document validation."
  @spec extract(term()) :: {:ok, term(), [term()]} | {:error, Error.t()}
  def extract(%{"attachments" => attachments} = document) when is_list(attachments) do
    attachments
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, [], []}, &extract_attachment/2)
    |> extracted_result(document)
  end

  def extract(document) do
    {:ok, document, []}
  end

  @doc "Decodes retained content only after canonical descriptor validation."
  @spec restore([Attachment.t()], [term()]) :: Error.result([Attachment.t()])
  def restore([], []) do
    {:ok, []}
  end

  def restore(attachments, retained_content) do
    attachments
    |> Enum.zip(retained_content)
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, &restore_attachment/2)
    |> reverse_attachments()
  end

  defp extract_attachment({attachment, index}, {:ok, descriptors, content})
       when is_map(attachment) do
    attachment
    |> Map.has_key?("content")
    |> extract_map_result(attachment, descriptors, content, index)
  end

  defp extract_attachment({attachment, _index}, {:ok, descriptors, content}) do
    {:cont, {:ok, [attachment | descriptors], [:absent | content]}}
  end

  defp extract_descriptor(attachment, descriptors, content) do
    {encoded, descriptor} = Map.pop(attachment, "content_base64", :absent)
    {:cont, {:ok, [descriptor | descriptors], [encoded | content]}}
  end

  defp extract_map_result(true, _attachment, _descriptors, _content, index) do
    {:halt, raw_content_error(index)}
  end

  defp extract_map_result(false, attachment, descriptors, content, _index) do
    extract_descriptor(attachment, descriptors, content)
  end

  defp restore_attachment({{attachment, :absent}, _index}, {:ok, restored}) do
    {:cont, {:ok, [attachment | restored]}}
  end

  defp restore_attachment({{attachment, encoded}, index}, {:ok, restored}) do
    case decode_content(encoded, index) do
      {:ok, content} -> rebuild_attachment(attachment, content, restored, index)
      {:error, %Error{}} = result -> {:halt, result}
    end
  end

  defp decode_content(encoded, index)
       when is_binary(encoded) and byte_size(encoded) <= @maximum_encoded_bytes do
    case Base.decode64(encoded) do
      {:ok, content} -> {:ok, content}
      :error -> invalid_content(index, :invalid_format, "must contain valid Base64")
    end
  end

  defp decode_content(encoded, index) when is_binary(encoded) do
    invalid_content(index, :too_large, "encoded attachment content is too large")
  end

  defp decode_content(_encoded, index) do
    invalid_content(index, :invalid_type, "must be a Base64 string")
  end

  defp rebuild_attachment(attachment, content, restored, index) do
    attributes =
      attachment
      |> Map.from_struct()
      |> Map.put(:content, content)

    case Attachment.new(attributes) do
      {:ok, rebuilt} -> {:cont, {:ok, [rebuilt | restored]}}
      {:error, %Error{} = error} -> {:halt, {:error, prefix_error(error, index)}}
    end
  end

  defp invalid_content(index, code, message) do
    Error.single([:attachments, index, :content_base64], code, message)
  end

  defp raw_content_error(index) do
    Error.single(
      [:attachments, index, :content],
      :unknown_key,
      "raw attachment content is not supported by the text format"
    )
  end

  defp prefix_error(%Error{violations: violations}, index) do
    prefixed =
      Enum.map(violations, fn violation ->
        %{violation | path: [:attachments, index | violation.path]}
      end)

    Error.new(prefixed)
  end

  defp reverse_attachments({:ok, attachments}) do
    {:ok, Enum.reverse(attachments)}
  end

  defp reverse_attachments({:error, %Error{}} = result) do
    result
  end

  defp extracted_result({:ok, descriptors, content}, document) do
    descriptor_document = Map.put(document, "attachments", Enum.reverse(descriptors))
    {:ok, descriptor_document, Enum.reverse(content)}
  end

  defp extracted_result({:error, %Error{}} = result, _document) do
    result
  end
end
