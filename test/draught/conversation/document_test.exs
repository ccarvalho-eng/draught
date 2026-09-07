defmodule Draught.Conversation.DocumentTest do
  use ExUnit.Case, async: true

  alias Draught.Conversation
  alias Draught.Conversation.Attachment
  alias Draught.Conversation.Content.Text
  alias Draught.Conversation.Document
  alias Draught.Conversation.Document.Messages.Limits
  alias Draught.Conversation.Message.Assistant
  alias Draught.Conversation.Message.User
  alias Draught.Provider.Usage
  alias Draught.Validation.Error

  test "constructs a versioned document from canonical conversation values" do
    {:ok, user} = Conversation.user("Review this module")
    {:ok, assistant} = Conversation.assistant(content: "It is valid")
    {:ok, usage} = Usage.new(input_tokens: 10, output_tokens: 4)

    {:ok, attachment} =
      Attachment.new(name: "notes.txt", media_type: "text/plain", content: "context")

    assert {:ok, document} =
             Document.new(
               messages: [user, assistant],
               usage: usage,
               metadata: %{"created_at" => "2026-09-07T00:00:00Z", "title" => "Review"},
               attachments: [attachment]
             )

    assert document.schema_version == 1
    assert document.messages == [user, assistant]
    assert document.usage == usage
    assert document.attachments == [attachment]
  end

  test "normalizes maps and revalidates nested structs" do
    attributes = %{
      "messages" => [%{"role" => "user", "content" => "Hello"}],
      "metadata" => %{},
      "usage" => %{"input_tokens" => 2, "output_tokens" => 1}
    }

    assert {:ok, document} = Document.new(attributes)
    assert [%User{}] = document.messages
    assert %Usage{total_tokens: 3} = document.usage
  end

  test "rejects unsupported versions and empty message collections" do
    assert {:error, %Error{violations: [violation]}} =
             Document.new(schema_version: 2, messages: [%{"role" => "user", "content" => "ok"}])

    assert violation.path == [:schema_version]
    assert violation.code == :invalid_value

    assert {:error, %Error{}} = Document.new(messages: [])
    assert {:error, %Error{}} = Document.new(messages: :invalid)
  end

  test "accepts the canonical content-filtered assistant placeholder" do
    filtered = Assistant.filtered()

    assert {:ok, document} = Document.new(messages: [filtered])
    assert document.messages == [filtered]

    assert {:ok, imported} =
             Document.new(messages: [%{"role" => "assistant", "filtered" => true}])

    assert imported.messages == [filtered]
  end

  test "rejects oversized message content with a specific bounded-input violation" do
    oversized = String.duplicate("x", Limits.max_message_bytes())

    assert {:error, %Error{violations: [violation]}} =
             Document.new(messages: [%{"role" => "user", "content" => oversized}])

    assert violation.path == [:messages, 0]
    assert violation.code == :too_large
  end

  test "accepts messages at the inclusive per-message and aggregate byte limits" do
    empty_message = %User{content: %Text{text: ""}}
    content_bytes = Limits.max_message_bytes() - :erlang.external_size(empty_message)
    content = String.duplicate("x", content_bytes)
    message = %{"role" => "user", "content" => content}

    assert {:ok, single} = Document.new(messages: [message])

    canonical_size =
      single.messages
      |> hd()
      |> :erlang.external_size()

    assert canonical_size == Limits.max_message_bytes()

    message_count = div(Limits.max_total_bytes(), Limits.max_message_bytes())
    messages = List.duplicate(message, message_count)

    assert {:ok, document} = Document.new(messages: messages)
    assert length(document.messages) == message_count

    revalidation_attributes = Map.from_struct(document)

    assert {:ok, revalidated} = Document.new(revalidation_attributes)
    assert revalidated == document
  end

  test "rejects an oversized aggregate of individually bounded messages" do
    content = String.duplicate("x", 3_145_728)
    messages = List.duplicate(%{"role" => "user", "content" => content}, 6)

    assert {:error, %Error{violations: [violation]}} = Document.new(messages: messages)

    assert violation.path == [:messages]
    assert violation.code == :too_large
  end

  test "bounds message count, attachment count, and declared attachment bytes" do
    {:ok, user} = Conversation.user("Hello")

    assert {:error, %Error{}} =
             Document.new(messages: List.duplicate(user, 1_001))

    assert {:error, %Error{}} =
             Document.new(messages: [user], attachments: List.duplicate(%{}, 65))

    attachments =
      Enum.map(1..5, fn index ->
        {:ok, attachment} =
          Attachment.new(
            name: "file#{index}.bin",
            media_type: "application/octet-stream",
            byte_size: Attachment.max_bytes(),
            sha256: digest("")
          )

        attachment
      end)

    assert {:error, %Error{}} = Document.new(messages: [user], attachments: attachments)
  end

  test "accepts collection limits and stops attachment work at the total byte boundary" do
    {:ok, user} = Conversation.user("Hello")
    messages = List.duplicate(user, 1_000)

    zero_sized =
      Enum.map(1..64, fn index ->
        {:ok, attachment} =
          Attachment.new(
            name: "empty#{index}.bin",
            media_type: "application/octet-stream",
            byte_size: 0,
            sha256: digest("")
          )

        attachment
      end)

    assert {:ok, _document} = Document.new(messages: messages, attachments: zero_sized)

    boundary =
      Enum.map(1..4, fn index ->
        {:ok, attachment} =
          Attachment.new(
            name: "boundary#{index}.bin",
            media_type: "application/octet-stream",
            byte_size: Attachment.max_bytes(),
            sha256: digest("")
          )

        attachment
      end)

    assert {:ok, _document} = Document.new(messages: [user], attachments: boundary)

    over_boundary =
      boundary ++
        [
          %{
            name: "overflow.bin",
            media_type: "application/octet-stream",
            byte_size: 1,
            sha256: digest("")
          },
          %{}
        ]

    assert {:error, %Error{violations: [violation]}} =
             Document.new(messages: [user], attachments: over_boundary)

    assert violation.path == [:attachments]
    assert violation.code == :too_large
  end

  test "rejects invalid metadata and duplicate portable attachment names" do
    {:ok, user} = Conversation.user("Hello")
    {:ok, first} = Attachment.new(name: "notes.txt", media_type: "text/plain", content: "a")
    {:ok, second} = Attachment.new(name: "NOTES.TXT", media_type: "text/plain", content: "b")

    assert {:error, %Error{}} = Document.new(messages: [user], metadata: %{atom: "value"})

    assert {:error, %Error{}} =
             Document.new(messages: [user], attachments: [first, second])
  end

  test "rejects malformed manually constructed nested values" do
    invalid_message = %User{content: %{text: ""}}

    invalid_attachment = %Attachment{
      name: "../secret",
      media_type: "text/plain",
      byte_size: 1,
      sha256: String.duplicate("0", 64),
      content: "x"
    }

    assert {:error, %Error{violations: [message_violation]}} =
             Document.new(messages: [invalid_message])

    assert message_violation.path == [:messages, 0, :content]
    assert message_violation.code == :invalid_type

    assert {:error, %Error{violations: [attachment_violation]}} =
             Document.new(
               messages: [%{"role" => "user", "content" => "ok"}],
               attachments: [invalid_attachment]
             )

    assert attachment_violation.path == [:attachments, 0, :name]
    assert attachment_violation.code == :invalid_value
  end

  test "keeps imported metadata inert as JSON data" do
    {:ok, document} =
      Document.new(
        messages: [%{"role" => "user", "content" => "Hello"}],
        metadata: %{
          "approval" => true,
          "provider" => %{"api_key" => "untrusted"},
          "workspace" => "/outside"
        }
      )

    assert document.metadata["approval"] == true

    document_fields = Map.from_struct(document)
    refute Map.has_key?(document_fields, :approval)
    refute Map.has_key?(document_fields, :provider)
    refute Map.has_key?(document_fields, :workspace)
  end

  defp digest(content) do
    content
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
