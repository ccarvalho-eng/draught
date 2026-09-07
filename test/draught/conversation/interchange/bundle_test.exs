defmodule Draught.Conversation.Interchange.BundleTest do
  use ExUnit.Case, async: false

  alias Draught.Conversation.Attachment
  alias Draught.Conversation.Document
  alias Draught.Conversation.Interchange.Bundle
  alias Draught.Conversation.Interchange.Text
  alias Draught.Conversation.Message.Assistant
  alias Draught.Conversation.Message.Tool
  alias Draught.Validation.Error

  @retain_all [:metadata, :reasoning, :tool_arguments, :tool_results]

  test "round-trips a conversation without attachments" do
    {:ok, document} = Document.new(messages: [%{"role" => "user", "content" => "hello"}])

    assert {:ok, archive} = Bundle.encode(document)
    assert {:ok, ^document} = Bundle.decode(archive)
  end

  test "encodes deterministic bundles and round-trips retained conversation data" do
    document = representative_document()

    assert {:ok, first} = Bundle.encode(document, retain: @retain_all)
    assert {:ok, second} = Bundle.encode(document, retain: Enum.reverse(@retain_all))
    assert first == second

    assert {:ok, decoded} = Bundle.decode(first)
    assert decoded == document

    assert {:ok, entries} = :zip.table(first)
    names = entry_names(entries)

    assert names == ["conversation.lmml", "attachments/sample.bin"]
  end

  test "uses the bundle call as attachment opt-in while retaining text redaction defaults" do
    document = representative_document()

    assert {:ok, archive} = Bundle.encode(document)
    assert {:ok, decoded} = Bundle.decode(archive)

    assert decoded.metadata == %{}

    assert [%Attachment{content: <<0, 1, 2, 3>>}, %Attachment{content: nil}] =
             decoded.attachments

    assert [_user, %Assistant{} = assistant, %Tool{} = tool] = decoded.messages
    assert Enum.any?(assistant.content, &(&1.text == "[reasoning redacted]"))
    assert [%{arguments: %{}}] = assistant.tool_calls
    assert tool.result.content == "[tool result redacted]"
  end

  test "keeps attachment bytes outside the text manifest" do
    document = representative_document()

    assert {:ok, archive} = Bundle.encode(document, retain: @retain_all)
    assert {:ok, [{_name, manifest}]} = extract(archive, ["conversation.lmml"])

    refute manifest =~ Base.encode64(<<0, 1, 2, 3>>)
    assert {:ok, manifest_document} = Text.decode(manifest)
    assert Enum.all?(manifest_document.attachments, &is_nil(&1.content))
  end

  test "rejects malformed archives and invalid declared central-directory counts" do
    assert_violation(Bundle.decode("not a zip"), :invalid_format)

    archive = zip([{"conversation.lmml", valid_manifest()}])
    forged = replace_entry_count(archive, 100)

    two_entries =
      zip([
        {"conversation.lmml", valid_manifest()},
        {"attachments/extra.txt", "extra"}
      ])

    underreported = replace_entry_count(two_entries, 1)

    assert_violation(Bundle.decode(forged), :too_large)
    assert_violation(Bundle.decode(underreported), :invalid_format)
  end

  test "rejects unsupported flags, split disks, ZIP64, comments, and inconsistent sizes" do
    archive = zip([{"conversation.lmml", valid_manifest()}])

    invalid_archives = [
      replace_last_central_u16(archive, 8, 0x8),
      replace_end_record_u16(archive, 4, 1),
      replace_last_central_u32(archive, 20, 0xFFFFFFFF),
      add_archive_comment(archive),
      add_entry_comment(archive),
      replace_last_central_u32(archive, 20, 1)
    ]

    Enum.each(invalid_archives, fn invalid ->
      assert {:error, %Error{}} = Bundle.decode(invalid)
    end)
  end

  test "rejects local headers that disagree with the central directory" do
    archive = zip([{"conversation.lmml", valid_manifest()}])

    mismatches = [
      replace_last_local_u16(archive, 8, 8),
      replace_last_local_u16(archive, 6, 0x800),
      replace_last_local_u32(archive, 14, 0),
      replace_last_local_u32(archive, 18, 1),
      replace_last_local_name(archive, ?x)
    ]

    Enum.each(mismatches, fn mismatch ->
      assert_violation(Bundle.decode(mismatch), :invalid_format)
    end)
  end

  test "rejects invalid UTF-8 entry names" do
    archive =
      zip([
        {"conversation.lmml", manifest_with_descriptors([descriptor("a.txt", "a")])},
        {"attachments/a.txt", "a"}
      ])

    invalid_name = <<"attachments/a.tx", 0xFF>>
    forged = :binary.replace(archive, "attachments/a.txt", invalid_name, [:global])

    assert_violation(Bundle.decode(forged), :invalid_value)
  end

  test "rejects missing, duplicate, case-colliding, and unknown entry paths" do
    missing_manifest = zip([{"attachments/a.txt", "a"}])

    duplicate_manifest =
      zip([
        {"conversation.lmml", valid_manifest()},
        {"conversation.lmml", valid_manifest()}
      ])

    case_collision =
      zip([
        {"conversation.lmml", manifest_with_descriptors([descriptor("a.txt", "a")])},
        {"attachments/a.txt", "a"},
        {"attachments/A.TXT", "a"}
      ])

    unknown = zip([{"conversation.lmml", valid_manifest()}, {"other.txt", "data"}])

    assert_violation(Bundle.decode(missing_manifest), :required)
    assert_violation(Bundle.decode(duplicate_manifest), :duplicate_key)
    assert_violation(Bundle.decode(case_collision), :duplicate_key)
    assert_violation(Bundle.decode(unknown), :invalid_value)
  end

  test "rejects traversal, absolute, backslash, directory, and symlink entries" do
    manifest = valid_manifest()

    invalid_paths = [
      "attachments/../secret",
      "attachments\\secret",
      "attachments/"
    ]

    Enum.each(invalid_paths, fn path ->
      archive = zip([{"conversation.lmml", manifest}, {path, "data"}])
      assert_violation(Bundle.decode(archive), :invalid_value)
    end)

    relative = zip([{"conversation.lmml", manifest}, {"xattachments/secret", "data"}])

    absolute =
      :binary.replace(relative, "xattachments/secret", "/attachments/secret", [:global])

    assert_violation(Bundle.decode(absolute), :invalid_value)

    symlink =
      mark_last_entry_as_symlink(
        zip([
          {"conversation.lmml", manifest},
          {"attachments/link", "target"}
        ])
      )

    assert_violation(Bundle.decode(symlink), :invalid_value)
  end

  test "rejects oversized entries and compressed archives before extraction" do
    oversized = :binary.copy("x", Attachment.max_bytes() + 1)

    oversized_archive =
      zip([
        {"conversation.lmml", valid_manifest()},
        {"attachments/large.bin", oversized}
      ])

    bomb = :binary.copy("a", 1_048_576)

    bomb_archive =
      zip(
        [
          {"conversation.lmml", valid_manifest()},
          {"attachments/bomb.txt", bomb}
        ],
        compress: :all
      )

    assert_violation(Bundle.decode(oversized_archive), :too_large)
    assert_violation(Bundle.decode(bomb_archive), :invalid_value)
  end

  test "rejects aggregate content and archive input above their limits" do
    chunk = :binary.copy("a", Attachment.max_bytes())

    entries =
      for index <- 1..6 do
        {"attachments/#{index}.bin", chunk}
      end

    aggregate_archive = zip([{"conversation.lmml", valid_manifest()} | entries])
    oversized_archive = :binary.copy(<<0>>, Bundle.max_input_bytes() + 1)

    assert_violation(Bundle.decode(aggregate_archive), :too_large)
    assert_violation(Bundle.decode(oversized_archive), :too_large)
  end

  test "rejects attachment entries absent from the manifest and missing from descriptors" do
    archive =
      zip([
        {"conversation.lmml", valid_manifest()},
        {"attachments/extra.txt", "PAYLOAD"}
      ])

    extra_entry = :binary.replace(archive, "PAYLOAD", "BROKEN!", [:global])

    missing_entry_manifest =
      manifest_with_descriptors([descriptor("present.txt", "present")])

    wrong_name =
      zip([
        {"conversation.lmml", missing_entry_manifest},
        {"attachments/other.txt", "present"}
      ])

    assert_violation(Bundle.decode(extra_entry), :invalid_relationship)
    assert_violation(Bundle.decode(wrong_name), :invalid_relationship)
  end

  test "rejects attachment bytes that do not match manifest size or digest" do
    descriptor = descriptor("sample.txt", "expected")
    manifest = manifest_with_descriptors([descriptor])

    wrong_size =
      zip([
        {"conversation.lmml", manifest},
        {"attachments/sample.txt", "different"}
      ])

    wrong_digest =
      zip([
        {"conversation.lmml", manifest},
        {"attachments/sample.txt", "tampered"}
      ])

    assert_violation(Bundle.decode(wrong_size), :invalid_relationship)
    assert_violation(Bundle.decode(wrong_digest), :invalid_relationship)
  end

  test "rejects malformed manifests without extracting attachment content" do
    archive =
      zip([
        {"conversation.lmml", "@@@draught.json\n{invalid}\n@@@\n"},
        {"attachments/sample.txt", "data"}
      ])

    assert_violation(Bundle.decode(archive), :invalid_format)
  end

  test "rejects attachment content embedded in the text manifest" do
    assert {:ok, manifest} = Text.encode(representative_document(), retain: [:attachment_content])

    archive = zip([{"conversation.lmml", manifest}])

    assert_violation(Bundle.decode(archive), :invalid_relationship)
  end

  test "requires the bundle manifest to contain the authoritative extension" do
    archive = zip([{"conversation.lmml", "plain markdown"}])

    assert_violation(Bundle.decode(archive), :invalid_format)
  end

  test "rejects invalid API inputs and unknown options" do
    document = representative_document()

    assert_violation(Bundle.encode(%{document | schema_version: 99}), :invalid_value)
    assert_violation(Bundle.encode(document, unknown: true), :unknown_key)
    assert_violation(Bundle.decode(:not_binary), :invalid_type)
  end

  defp representative_document do
    {:ok, retained} =
      Attachment.new(
        name: "sample.bin",
        media_type: "application/octet-stream",
        content: <<0, 1, 2, 3>>
      )

    {:ok, descriptor_only} =
      Attachment.new(
        name: "reference.txt",
        media_type: "text/plain",
        byte_size: 7,
        sha256: sha256("missing")
      )

    {:ok, document} =
      Document.new(
        messages: [
          %{"role" => "user", "content" => "Inspect this"},
          %{
            "role" => "assistant",
            "content" => [
              %{"type" => "reasoning", "text" => "private reasoning"},
              %{"type" => "text", "text" => "Reading"}
            ],
            "tool_calls" => [
              %{
                "id" => "call-1",
                "name" => "read_file",
                "arguments" => %{"path" => "private.txt"}
              }
            ]
          },
          %{
            "role" => "tool",
            "result" => %{
              "call_id" => "call-1",
              "name" => "read_file",
              "content" => "private output"
            }
          }
        ],
        usage: %{"input_tokens" => 4, "output_tokens" => 3},
        metadata: %{"private" => true},
        attachments: [retained, descriptor_only]
      )

    document
  end

  defp valid_manifest do
    {:ok, document} = Document.new(messages: [%{"role" => "user", "content" => "hello"}])
    {:ok, manifest} = Text.encode(document)
    manifest
  end

  defp manifest_with_descriptors(descriptors) do
    {:ok, document} =
      Document.new(
        messages: [%{"role" => "user", "content" => "hello"}],
        attachments: descriptors
      )

    {:ok, manifest} = Text.encode(document, retain: [:attachments])
    manifest
  end

  defp descriptor(name, content) do
    %{
      "name" => name,
      "media_type" => "application/octet-stream",
      "byte_size" => byte_size(content),
      "sha256" => sha256(content)
    }
  end

  defp zip(files, options \\ [uncompress: :all]) do
    specs =
      Enum.map(files, fn
        {name, content} -> {String.to_charlist(name), content}
        {name, content, info} -> {String.to_charlist(name), content, info}
      end)

    {:ok, {_name, archive}} = :zip.create(~c"test.lmmlz", specs, [:memory | options])
    archive
  end

  defp extract(archive, names) do
    charlist_names = Enum.map(names, &String.to_charlist/1)
    :zip.extract(archive, [:memory, {:file_list, charlist_names}])
  end

  defp entry_names(entries) do
    Enum.flat_map(entries, fn
      {:zip_file, name, _info, _comment, _offset, _compressed_size} ->
        [List.to_string(name)]

      {:zip_comment, _comment} ->
        []
    end)
  end

  defp replace_entry_count(archive, count) do
    signature = <<0x06054B50::little-32>>
    offsets = :binary.matches(archive, signature)
    {offset, _length} = :lists.last(offsets)
    count_offset = offset + 8

    <<prefix::binary-size(^count_offset), _old_counts::binary-size(4), suffix::binary>> = archive
    prefix <> <<count::little-16, count::little-16>> <> suffix
  end

  defp replace_last_central_u16(archive, relative_offset, value) do
    replace_last_header_u16(archive, <<0x02014B50::little-32>>, relative_offset, value)
  end

  defp replace_last_central_u32(archive, relative_offset, value) do
    replace_last_header_u32(archive, <<0x02014B50::little-32>>, relative_offset, value)
  end

  defp replace_last_local_u16(archive, relative_offset, value) do
    replace_last_header_u16(archive, <<0x04034B50::little-32>>, relative_offset, value)
  end

  defp replace_last_local_u32(archive, relative_offset, value) do
    replace_last_header_u32(archive, <<0x04034B50::little-32>>, relative_offset, value)
  end

  defp replace_end_record_u16(archive, relative_offset, value) do
    replace_last_header_u16(archive, <<0x06054B50::little-32>>, relative_offset, value)
  end

  defp replace_last_header_u16(archive, signature, relative_offset, value) do
    offset = last_signature_offset(archive, signature) + relative_offset
    <<prefix::binary-size(^offset), _old::little-16, suffix::binary>> = archive
    prefix <> <<value::little-16>> <> suffix
  end

  defp replace_last_header_u32(archive, signature, relative_offset, value) do
    offset = last_signature_offset(archive, signature) + relative_offset
    <<prefix::binary-size(^offset), _old::little-32, suffix::binary>> = archive
    prefix <> <<value::little-32>> <> suffix
  end

  defp replace_last_local_name(archive, replacement) do
    offset = last_signature_offset(archive, <<0x04034B50::little-32>>) + 30
    <<prefix::binary-size(^offset), _old, suffix::binary>> = archive
    prefix <> <<replacement>> <> suffix
  end

  defp add_archive_comment(archive) do
    archive
    |> replace_end_record_u16(20, 1)
    |> Kernel.<>("x")
  end

  defp add_entry_comment(archive) do
    signature = <<0x06054B50::little-32>>
    end_offset = last_signature_offset(archive, signature)
    directory_size = read_u32(archive, end_offset + 12)

    <<directory::binary-size(^end_offset), end_record::binary>> = archive

    expanded = directory <> "x" <> end_record

    expanded
    |> replace_last_central_u16(32, 1)
    |> replace_last_header_u32(signature, 12, directory_size + 1)
  end

  defp read_u32(archive, offset) do
    <<_prefix::binary-size(^offset), value::little-32, _suffix::binary>> = archive
    value
  end

  defp last_signature_offset(archive, signature) do
    archive
    |> :binary.matches(signature)
    |> :lists.last()
    |> elem(0)
  end

  defp mark_last_entry_as_symlink(archive) do
    signature = <<0x02014B50::little-32>>
    matches = :binary.matches(archive, signature)
    {offset, _length} = :lists.last(matches)
    attributes_offset = offset + 38
    symlink_attributes = 0o120777 * 65_536

    <<prefix::binary-size(^attributes_offset), _attributes::little-32, suffix::binary>> = archive
    prefix <> <<symlink_attributes::little-32>> <> suffix
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
