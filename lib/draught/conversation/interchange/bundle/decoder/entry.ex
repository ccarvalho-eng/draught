defmodule Draught.Conversation.Interchange.Bundle.Decoder.Entry do
  @moduledoc false

  alias Draught.Conversation.Attachment
  alias Draught.Conversation.Attachment.Name
  alias Draught.Conversation.Interchange.Bundle.Entry
  alias Draught.Conversation.Interchange.Text
  alias Draught.Validation.Error

  @attachment_prefix "attachments/"
  @maximum_attachment_bytes Attachment.max_bytes()
  @maximum_manifest_bytes Text.max_input_bytes()

  @doc "Validates one raw ZIP table entry."
  @spec new(term(), term(), term(), term(), term(), non_neg_integer()) :: Error.result(Entry.t())
  def new(archive_name, type, size, compressed_size, comment, index) do
    with {:ok, path} <- path(archive_name, index),
         :ok <- regular_type(type, index),
         :ok <- empty_comment(comment, index),
         :ok <- sizes(size, compressed_size, index),
         {:ok, identity} <- identity(path, size, index),
         :ok <- stored_sizes(size, compressed_size, index) do
      {:ok,
       %Entry{
         path: path,
         kind: identity.kind,
         name: identity.name,
         size: size,
         compressed_size: compressed_size,
         archive_name: archive_name
       }}
    end
  end

  defp path(name, index) when is_list(name) do
    case :unicode.characters_to_binary(name) do
      path when is_binary(path) -> {:ok, path}
      _error -> Error.single([:entries, index, :path], :invalid_value, "must be valid UTF-8")
    end
  end

  defp path(_name, index) do
    Error.single([:entries, index, :path], :invalid_type, "must be a character list")
  end

  defp regular_type(:regular, _index) do
    :ok
  end

  defp regular_type(_type, index) do
    Error.single([:entries, index, :type], :invalid_value, "must be a regular file")
  end

  defp empty_comment([], _index) do
    :ok
  end

  defp empty_comment(_comment, index) do
    Error.single([:entries, index, :comment], :invalid_value, "entry comments are not supported")
  end

  defp sizes(size, compressed_size, _index)
       when is_integer(size) and size >= 0 and is_integer(compressed_size) and
              compressed_size >= 0 do
    :ok
  end

  defp sizes(_size, _compressed_size, index) do
    Error.single([:entries, index], :invalid_value, "must contain valid non-negative sizes")
  end

  defp identity("conversation.lmml", size, _index) when size <= @maximum_manifest_bytes do
    {:ok, %{kind: :manifest, name: nil}}
  end

  defp identity("conversation.lmml", _size, index) do
    Error.single([:entries, index, :size], :too_large, "manifest exceeds the text limit")
  end

  defp identity(<<@attachment_prefix, name::binary>>, size, index)
       when size <= @maximum_attachment_bytes do
    case Name.validate(name, [:entries, index, :path]) do
      {:ok, portable} -> {:ok, %{kind: :attachment, name: portable}}
      {:error, %Error{}} = result -> result
    end
  end

  defp identity(<<@attachment_prefix, _name::binary>>, _size, index) do
    Error.single([:entries, index, :size], :too_large, "attachment exceeds the entry limit")
  end

  defp identity(_path, _size, index) do
    Error.single([:entries, index, :path], :invalid_value, "is not an allowed bundle path")
  end

  defp stored_sizes(size, size, _index) do
    :ok
  end

  defp stored_sizes(_size, _compressed_size, index) do
    Error.single([:entries, index], :invalid_format, "stored size values must match")
  end
end
