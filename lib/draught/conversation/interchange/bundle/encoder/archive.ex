defmodule Draught.Conversation.Interchange.Bundle.Encoder.Archive do
  @moduledoc """
  Constructs deterministic in-memory ZIP archives for conversation bundles.

  Entries are stored without compression, use fixed metadata, and order
  attachment files case-insensitively after the manifest.
  """

  alias Draught.Conversation.Attachment
  alias Draught.Validation.Error

  require Record

  Record.defrecordp(
    :file_info,
    Record.extract(:file_info, from_lib: "kernel/include/file.hrl")
  )

  @archive_name ~c"conversation.lmmlz"
  @manifest_name ~c"conversation.lmml"
  @timestamp {{1980, 1, 1}, {0, 0, 0}}

  @doc "Creates deterministic, uncompressed in-memory ZIP bytes."
  @spec create(binary(), [Attachment.t()]) :: Error.result(binary())
  def create(manifest, attachments) do
    files = [file(@manifest_name, manifest) | attachment_files(attachments)]

    case :zip.create(@archive_name, files, [:memory, {:uncompress, :all}, {:extra, []}]) do
      {:ok, {_name, archive}} -> {:ok, archive}
      {:error, _reason} -> Error.single([], :invalid_format, "could not create bundle")
    end
  end

  defp attachment_files(attachments) do
    attachments
    |> Enum.filter(&is_binary(&1.content))
    |> Enum.sort_by(&String.downcase(&1.name))
    |> Enum.map(fn attachment ->
      name = ~c"attachments/" ++ String.to_charlist(attachment.name)
      file(name, attachment.content)
    end)
  end

  defp file(name, content) do
    {name, content, regular_file_info(byte_size(content))}
  end

  defp regular_file_info(size) do
    file_info(
      size: size,
      type: :regular,
      access: :read_write,
      atime: @timestamp,
      mtime: @timestamp,
      ctime: @timestamp,
      mode: 0o644,
      links: 1,
      major_device: 0,
      minor_device: 0,
      inode: 0,
      uid: 0,
      gid: 0
    )
  end
end
