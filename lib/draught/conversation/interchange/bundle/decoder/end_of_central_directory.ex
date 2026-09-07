defmodule Draught.Conversation.Interchange.Bundle.Decoder.EndOfCentralDirectory do
  @moduledoc """
  Parses the terminal ZIP directory record under bundle limits.

  Multi-disk and ZIP64 layouts are rejected, and the central-directory bounds
  must end exactly where the terminal record begins.
  """

  alias Draught.Validation.Error

  @signature <<0x06054B50::little-32>>
  @record_bytes 22
  @maximum_comment_bytes 65_535

  @doc "Validates the terminal ZIP directory record before table allocation."
  @type t :: %{
          entries: non_neg_integer(),
          directory_size: non_neg_integer(),
          directory_offset: non_neg_integer()
        }

  @spec validate(binary(), pos_integer()) :: Error.result(t())
  def validate(archive, maximum_entries) do
    with {:ok, offset} <- locate(archive),
         {:ok, fields} <- parse(archive, offset),
         :ok <- validate_disks(fields),
         :ok <- validate_count(fields, maximum_entries),
         :ok <- validate_bounds(fields, offset) do
      {:ok,
       %{
         entries: fields.entries,
         directory_size: fields.directory_size,
         directory_offset: fields.directory_offset
       }}
    end
  end

  defp locate(archive) do
    archive_size = byte_size(archive)
    search_size = min(archive_size, @record_bytes + @maximum_comment_bytes)
    search_offset = archive_size - search_size
    window = binary_part(archive, search_offset, search_size)

    case :binary.matches(window, @signature) do
      [] -> Error.single([], :invalid_format, "does not contain a ZIP directory record")
      matches -> absolute_offset(:lists.last(matches), search_offset)
    end
  end

  defp absolute_offset({relative, _length}, search_offset) do
    {:ok, search_offset + relative}
  end

  defp parse(archive, offset) do
    record_size = byte_size(archive) - offset

    case binary_part(archive, offset, record_size) do
      <<@signature, disk::little-16, directory_disk::little-16, disk_entries::little-16,
        entries::little-16, directory_size::little-32, directory_offset::little-32,
        comment_size::little-16, comment::binary-size(comment_size)>> ->
        {:ok,
         %{
           disk: disk,
           directory_disk: directory_disk,
           disk_entries: disk_entries,
           entries: entries,
           directory_size: directory_size,
           directory_offset: directory_offset,
           comment: comment
         }}

      _record ->
        Error.single([], :invalid_format, "has a malformed ZIP directory record")
    end
  end

  defp validate_disks(%{disk: 0, directory_disk: 0, disk_entries: count, entries: count}) do
    :ok
  end

  defp validate_disks(_fields) do
    Error.single([], :invalid_format, "multi-disk and ZIP64 bundles are not supported")
  end

  defp validate_count(%{entries: count}, maximum_entries) when count <= maximum_entries do
    :ok
  end

  defp validate_count(_fields, maximum_entries) do
    Error.single([], :too_large, "bundle must not contain more than #{maximum_entries} entries")
  end

  defp validate_bounds(fields, directory_record_offset) do
    directory_end = fields.directory_offset + fields.directory_size

    bounds_result(directory_end == directory_record_offset)
  end

  defp bounds_result(true) do
    :ok
  end

  defp bounds_result(false) do
    Error.single([], :invalid_format, "has invalid central-directory bounds")
  end
end
