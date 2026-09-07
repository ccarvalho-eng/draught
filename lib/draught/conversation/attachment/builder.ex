defmodule Draught.Conversation.Attachment.Builder do
  @moduledoc """
  Builds canonical attachment fields from external attributes.

  Inline content is bounded before hashing. Declared byte sizes and digests
  must match inline content, while descriptor-only attachments must supply both.
  """

  alias Draught.Conversation.Attachment.Digest
  alias Draught.Conversation.Attachment.MediaType
  alias Draught.Conversation.Attachment.Name
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @doc "Builds normalized attachment fields within the configured byte limit."
  @spec build(term(), pos_integer()) :: Error.result(map())
  def build(attributes, maximum_bytes) do
    with {:ok, normalized} <- normalize_attributes(attributes),
         {:ok, identity} <- identity(normalized),
         {:ok, descriptor} <- descriptor(normalized, maximum_bytes) do
      {:ok, Map.merge(identity, descriptor)}
    end
  end

  defp normalize_attributes(attributes) do
    Attributes.normalize(attributes, [:name, :media_type, :byte_size, :sha256, :content])
  end

  defp identity(attributes) do
    with {:ok, raw_name} <- Attributes.fetch_required(attributes, :name),
         {:ok, name} <- Name.validate(raw_name, [:name]),
         {:ok, raw_media_type} <- Attributes.fetch_required(attributes, :media_type),
         {:ok, media_type} <- MediaType.validate(raw_media_type, [:media_type]) do
      {:ok, %{name: name, media_type: media_type}}
    end
  end

  defp descriptor(attributes, maximum_bytes) do
    with {:ok, content} <- content(attributes, maximum_bytes),
         {:ok, byte_size} <- declared_size(attributes, content, maximum_bytes),
         {:ok, sha256} <- declared_digest(attributes, content) do
      {:ok, %{byte_size: byte_size, sha256: sha256, content: content}}
    end
  end

  defp content(attributes, maximum_bytes) do
    attributes
    |> Map.get(:content)
    |> content_result(maximum_bytes)
  end

  defp content_result(nil, _maximum_bytes) do
    {:ok, nil}
  end

  defp content_result(content, maximum_bytes)
       when is_binary(content) and byte_size(content) <= maximum_bytes do
    {:ok, content}
  end

  defp content_result(content, maximum_bytes) when is_binary(content) do
    Error.single([:content], :too_large, "must not exceed #{maximum_bytes} bytes")
  end

  defp content_result(_content, _maximum_bytes) do
    Error.single([:content], :invalid_type, "must be binary content")
  end

  defp declared_size(attributes, nil, maximum_bytes) do
    with {:ok, size} <- Attributes.fetch_required(attributes, :byte_size) do
      validate_size(size, maximum_bytes)
    end
  end

  defp declared_size(attributes, content, maximum_bytes) do
    expected = byte_size(content)

    case Map.fetch(attributes, :byte_size) do
      {:ok, value} -> validate_expected_size(value, expected, maximum_bytes)
      :error -> {:ok, expected}
    end
  end

  defp validate_size(size, maximum_bytes) do
    with {:ok, validated} <- Value.non_negative_integer(size, [:byte_size]) do
      validate_maximum_size(validated, maximum_bytes)
    end
  end

  defp validate_expected_size(value, expected, maximum_bytes) do
    with {:ok, validated} <- validate_size(value, maximum_bytes) do
      expected_size_result(validated, expected)
    end
  end

  defp validate_maximum_size(size, maximum_bytes) when size <= maximum_bytes do
    {:ok, size}
  end

  defp validate_maximum_size(_size, maximum_bytes) do
    Error.single([:byte_size], :too_large, "must not exceed #{maximum_bytes} bytes")
  end

  defp expected_size_result(size, size) do
    {:ok, size}
  end

  defp expected_size_result(_size, _expected) do
    Error.single([:byte_size], :invalid_relationship, "must equal the content byte size")
  end

  defp declared_digest(attributes, nil) do
    with {:ok, digest} <- Attributes.fetch_required(attributes, :sha256) do
      Digest.validate(digest, [:sha256])
    end
  end

  defp declared_digest(attributes, content) do
    expected = Digest.from_content(content)

    case Map.fetch(attributes, :sha256) do
      {:ok, value} -> validate_expected_digest(value, expected)
      :error -> {:ok, expected}
    end
  end

  defp validate_expected_digest(value, expected) do
    with {:ok, validated} <- Digest.validate(value, [:sha256]) do
      expected_digest_result(validated, expected)
    end
  end

  defp expected_digest_result(digest, digest) do
    {:ok, digest}
  end

  defp expected_digest_result(_digest, _expected) do
    Error.single([:sha256], :invalid_relationship, "must match the content SHA-256 digest")
  end
end
