defmodule Draught.Conversation.Interchange.TextTest do
  use ExUnit.Case, async: true

  alias Draught.Conversation.Attachment
  alias Draught.Conversation.Document
  alias Draught.Conversation.Interchange.Text
  alias Draught.Conversation.Message.Assistant
  alias Draught.Conversation.Message.Tool
  alias Draught.Error.Normalized
  alias Draught.Validation.Error

  @retain_all [
    :attachment_content,
    :attachments,
    :metadata,
    :reasoning,
    :tool_arguments,
    :tool_results
  ]

  test "round-trips a representative document deterministically with explicit retention" do
    document = representative_document()

    assert {:ok, first} = Text.encode(document, retain: @retain_all)
    assert {:ok, second} = Text.encode(document, retain: Enum.reverse(@retain_all))
    assert first == second

    assert String.starts_with?(first, "@@@draught.json\n")
    assert first =~ "\n# Conversation\n"
    assert {:ok, decoded} = Text.decode(first)
    assert decoded == document

    assert {:ok, encoded_again} = Text.encode(decoded, retain: @retain_all)
    assert encoded_again == first
  end

  test "redacts sensitive fields by default without changing the input document" do
    document = representative_document()

    assert {:ok, encoded} = Text.encode(document)
    refute encoded =~ "private chain"
    refute encoded =~ "lib/secret.ex"
    refute encoded =~ "sensitive tool output"
    refute encoded =~ "private metadata"
    refute encoded =~ Base.encode64(<<0, 1, 2, 3>>)
    refute encoded =~ "sample.bin"

    assert {:ok, decoded} = Text.decode(encoded)
    assert decoded.metadata == %{}
    assert decoded.attachments == []

    assert [_user, %Assistant{} = assistant, %Tool{} = tool] = decoded.messages
    assert Enum.any?(assistant.content, &(&1.text == "[reasoning redacted]"))
    assert [%{arguments: %{}}] = assistant.tool_calls
    assert tool.result.content == "[tool result redacted]"
    assert tool.result.error.code == "redacted"
    assert tool.result.error.message == "Tool error details were redacted"

    assert representative_document() == document
  end

  test "keeps sensitive payloads out of the readable narrative even when retained" do
    document = representative_document()

    assert {:ok, encoded} = Text.encode(document, retain: @retain_all)
    [_extension, narrative] = String.split(encoded, "@@@\n\n", parts: 2)

    assert narrative =~ "## User"
    assert narrative =~ "## Assistant"
    assert narrative =~ "### Tool calls"
    assert narrative =~ "`read_file` (`call-1`)"
    assert narrative =~ "## Tool result: `read_file`"
    refute narrative =~ "private chain"
    refute narrative =~ "lib/secret.ex"
    refute narrative =~ "sensitive tool output"
    refute narrative =~ "private metadata"
  end

  test "retains attachment descriptors separately from attachment bytes" do
    document = representative_document()

    assert {:ok, encoded} = Text.encode(document, retain: [:attachments])
    assert {:ok, decoded} = Text.decode(encoded)

    assert [%Attachment{content: nil, name: "sample.bin"}] = decoded.attachments
  end

  test "imports plain Markdown as one user-authored message" do
    markdown =
      "# Review notes\n\nPlease inspect `lib/example.ex` and explain `@@@draught.json`."

    assert {:ok, document} = Text.decode(markdown)
    assert [%{content: %{text: ^markdown}}] = document.messages
    assert document.usage == nil
    assert document.metadata == %{}
    assert document.attachments == []
  end

  test "preserves the explicit filtered-assistant sentinel" do
    {:ok, document} = Document.new(messages: [%{"role" => "assistant", "filtered" => true}])

    assert {:ok, encoded} = Text.encode(document)
    assert {:ok, decoded} = Text.decode(encoded)
    assert [%Assistant{content: [], tool_calls: []}] = decoded.messages
  end

  test "rejects malformed, ambiguous, unsupported, and oversized extensions" do
    malformed = "@@@draught.json\n{not json}\n@@@\n\n# Conversation\n"
    unsupported = extension(%{"format" => "draught.conversation", "format_version" => 2})
    ambiguous = "# Notes\n\n@@@draught.json\n{}\n@@@"
    oversized = :binary.copy("x", Text.max_input_bytes() + 1)

    assert_violation(Text.decode(malformed), :invalid_format)
    assert_violation(Text.decode(unsupported), :unsupported_version)
    assert_violation(Text.decode(ambiguous), :invalid_format)
    assert_violation(Text.decode(oversized), :too_large)
  end

  test "rejects invalid UTF-8 and malformed retained attachment content" do
    invalid_utf8 = <<255, 254>>

    invalid_attachment =
      extension(%{
        "format" => "draught.conversation",
        "format_version" => 1,
        "document" => %{
          "schema_version" => 1,
          "messages" => [%{"role" => "user", "content" => "hello"}],
          "attachments" => [
            %{
              "name" => "sample.bin",
              "media_type" => "application/octet-stream",
              "byte_size" => 1,
              "sha256" => String.duplicate("0", 64),
              "content_base64" => "not base64"
            }
          ]
        }
      })

    assert_violation(Text.decode(invalid_utf8), :invalid_format)
    assert_violation(Text.decode(invalid_attachment), :invalid_format)
  end

  test "rejects excessive JSON depth before canonical reconstruction" do
    nested = String.duplicate("[", 33) <> String.duplicate("]", 33)

    artifact =
      "@@@draught.json\n" <>
        ~s({"format":"draught.conversation","format_version":1,"document":#{nested}}) <>
        "\n@@@\n\n# Conversation\n"

    assert_violation(Text.decode(artifact), :too_deep)
  end

  test "rejects excessively wide JSON before decoding and imports newline-dense Markdown" do
    wide_value = "[" <> String.duplicate("0,", 262_145) <> "0]"

    wide_artifact =
      raw_extension(
        ~s({"format":"draught.conversation","format_version":1,"document":#{wide_value}})
      )

    markdown = String.duplicate("\n", 10_000) <> "notes"

    assert_violation(Text.decode(wide_artifact), :too_large)
    assert {:ok, document} = Text.decode(markdown)
    assert [%{content: %{text: ^markdown}}] = document.messages
  end

  test "rejects duplicate JSON keys at header and nested document levels" do
    header_duplicate =
      raw_extension(
        ~s({"format":"draught.conversation","format":"other","format_version":1,"document":{"messages":[{"role":"user","content":"hello"}]}})
      )

    nested_duplicate =
      raw_extension(
        ~s({"format":"draught.conversation","format_version":1,"document":{"messages":[{"role":"user","content":"hello"}],"metadata":{"same":1,"same":2}}})
      )

    assert_violation(Text.decode(header_duplicate), :duplicate_key)
    assert_violation(Text.decode(nested_duplicate), :duplicate_key)
  end

  test "rejects internal raw attachment content at the wire boundary" do
    attachment =
      ~s({"name":"sample.txt","media_type":"text/plain","byte_size":3,"sha256":"#{sha256("raw")}","content":"raw"})

    raw_content =
      raw_extension(
        ~s({"format":"draught.conversation","format_version":1,"document":{"messages":[{"role":"user","content":"hello"}],"attachments":[#{attachment}]}})
      )

    both_content_forms =
      String.replace(
        raw_content,
        ~s("content":"raw"),
        ~s("content":"raw","content_base64":"cmF3")
      )

    assert_violation(Text.decode(raw_content), :unknown_key)
    assert_violation(Text.decode(both_content_forms), :unknown_key)
  end

  test "rejects unknown export options and malformed document structs" do
    document = representative_document()
    malformed = %{document | schema_version: 99}

    assert_violation(Text.encode(document, unknown: true), :unknown_key)
    assert_violation(Text.encode(document, retain: [:credentials]), :invalid_value)
    assert_violation(Text.encode(malformed), :invalid_value)
  end

  test "sorts arbitrary nested JSON keys deterministically" do
    document = representative_document()

    assert {:ok, encoded} = Text.encode(document, retain: @retain_all)

    assert position(encoded, "argument_alpha_unique") <
             position(encoded, "argument_zeta_unique")

    assert position(encoded, "metadata_alpha_unique") <
             position(encoded, "metadata_zeta_unique")

    assert position(encoded, "argument_nested_alpha_unique") <
             position(encoded, "argument_nested_zeta_unique")

    assert position(encoded, "metadata_nested_alpha_unique") <
             position(encoded, "metadata_nested_zeta_unique")
  end

  test "treats the extension as authoritative rather than importing rendered headings" do
    document = representative_document()

    assert {:ok, encoded} = Text.encode(document, retain: @retain_all)
    [extension, narrative] = String.split(encoded, "@@@\n\n", parts: 2)
    changed_narrative = String.replace(narrative, "Inspect the module", "Changed rendered text")
    changed = extension <> "@@@\n\n" <> changed_narrative

    assert {:ok, decoded} = Text.decode(changed)
    assert decoded == document
  end

  defp representative_document do
    {:ok, error} =
      Normalized.new(:tool, "read_failed", "sensitive failure", hint: "private hint")

    {:ok, attachment} =
      Attachment.new(
        name: "sample.bin",
        media_type: "application/octet-stream",
        content: <<0, 1, 2, 3>>
      )

    {:ok, document} =
      Document.new(
        messages: [
          %{"role" => "user", "content" => "Inspect the module"},
          %{
            "role" => "assistant",
            "content" => [
              %{"type" => "reasoning", "text" => "private chain"},
              %{"type" => "text", "text" => "I will inspect it"}
            ],
            "tool_calls" => [
              %{
                "id" => "call-1",
                "name" => "read_file",
                "arguments" => %{
                  "argument_zeta_unique" => true,
                  "path" => "lib/secret.ex",
                  "argument_alpha_unique" => %{
                    "argument_nested_zeta_unique" => 1,
                    "argument_nested_alpha_unique" => 2
                  }
                }
              }
            ]
          },
          %{
            "role" => "tool",
            "result" => %{
              "call_id" => "call-1",
              "name" => "read_file",
              "content" => "sensitive tool output",
              "status" => "error",
              "error" => Map.from_struct(error)
            }
          }
        ],
        usage: %{
          "input_tokens" => 12,
          "output_tokens" => 6,
          "cached_tokens" => 2,
          "reasoning_tokens" => 3
        },
        metadata: %{
          "metadata_zeta_unique" => "private metadata",
          "metadata_alpha_unique" => %{
            "metadata_nested_zeta_unique" => 1,
            "metadata_nested_alpha_unique" => true
          }
        },
        attachments: [attachment]
      )

    document
  end

  defp extension(header) do
    "@@@draught.json\n" <> Jason.encode!(header) <> "\n@@@\n\n# Conversation\n"
  end

  defp raw_extension(json) do
    "@@@draught.json\n" <> json <> "\n@@@\n\n# Conversation\n"
  end

  defp position(haystack, needle) do
    {offset, _length} = :binary.match(haystack, needle)
    offset
  end

  defp sha256(content) do
    content
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp assert_violation(result, code) do
    assert {:error, %Error{violations: violations}} = result
    assert Enum.any?(violations, &(&1.code == code))
  end
end
