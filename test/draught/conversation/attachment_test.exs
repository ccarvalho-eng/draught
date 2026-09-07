defmodule Draught.Conversation.AttachmentTest do
  use ExUnit.Case, async: true

  alias Draught.Conversation.Attachment
  alias Draught.Validation.Error

  test "derives stable descriptor fields from included content" do
    assert {:ok, attachment} =
             Attachment.new(
               name: "notes.txt",
               media_type: "text/plain",
               content: "hello"
             )

    assert attachment.name == "notes.txt"
    assert attachment.media_type == "text/plain"
    assert attachment.byte_size == 5
    assert attachment.sha256 == digest("hello")
    assert attachment.content == "hello"
  end

  test "accepts a descriptor without retained content" do
    assert {:ok, attachment} =
             Attachment.new(
               name: "image.png",
               media_type: "image/png",
               byte_size: 4,
               sha256: digest("data")
             )

    assert attachment.content == nil
  end

  test "rejects unsafe or non-portable names" do
    invalid_names = [
      "",
      ".",
      "..",
      ".hidden",
      "../secret",
      "a/b",
      "a\\b",
      "two words",
      "notes.",
      "CON",
      "nul.txt",
      "LPT9.log"
    ]

    Enum.each(invalid_names, fn name ->
      assert {:error, %Error{}} =
               Attachment.new(name: name, media_type: "text/plain", content: "content")
    end)
  end

  test "rejects malformed media types and inconsistent descriptors" do
    assert {:error, %Error{}} =
             Attachment.new(name: "notes.txt", media_type: "text", content: "hello")

    assert {:error, %Error{}} =
             Attachment.new(
               name: "notes.txt",
               media_type: "text/plain",
               content: "hello",
               byte_size: 4
             )

    assert {:error, %Error{}} =
             Attachment.new(
               name: "notes.txt",
               media_type: "text/plain",
               content: "hello",
               sha256: String.duplicate("0", 64)
             )
  end

  test "rejects malformed or oversized descriptor metadata" do
    assert {:error, %Error{}} =
             Attachment.new(
               name: "notes.txt",
               media_type: "Text/Plain",
               byte_size: 0,
               sha256: digest("")
             )

    assert {:error, %Error{}} =
             Attachment.new(
               name: "notes.txt",
               media_type: "text/plain",
               byte_size: Attachment.max_bytes() + 1,
               sha256: digest("")
             )

    assert {:error, %Error{}} =
             Attachment.new(
               name: "notes.txt",
               media_type: "text/plain",
               byte_size: 0,
               sha256: "invalid"
             )

    assert {:error, %Error{}} =
             Attachment.new(name: "notes.txt", media_type: "text/plain", content: 42)
  end

  test "rejects content larger than the attachment boundary" do
    content = :binary.copy(<<0>>, Attachment.max_bytes() + 1)

    assert {:error, %Error{}} =
             Attachment.new(
               name: "large.bin",
               media_type: "application/octet-stream",
               content: content
             )
  end

  test "accepts retained content at the attachment byte boundary" do
    content = :binary.copy(<<0>>, Attachment.max_bytes())

    assert {:ok, attachment} =
             Attachment.new(
               name: "large.bin",
               media_type: "application/octet-stream",
               content: content
             )

    assert attachment.byte_size == Attachment.max_bytes()
    assert attachment.sha256 == digest(content)
    assert attachment.content == content
  end

  defp digest(content) do
    content
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
