defmodule Draught.Conversation.Interchange.Bundle.Decoder.Table do
  @moduledoc false

  alias Draught.Conversation.Interchange.Bundle.Entry
  alias Draught.Validation.Error

  require Record

  Record.defrecordp(:zip_file, Record.extract(:zip_file, from_lib: "stdlib/include/zip.hrl"))

  Record.defrecordp(
    :zip_comment,
    Record.extract(:zip_comment, from_lib: "stdlib/include/zip.hrl")
  )

  Record.defrecordp(:file_info, Record.extract(:file_info, from_lib: "kernel/include/file.hrl"))

  @maximum_total_bytes 100_663_296

  @doc "Reads and validates the archive table without extracting entries."
  @spec read(binary(), non_neg_integer()) :: Error.result([Entry.t()])
  def read(archive, expected_count) do
    case safe_table(archive) do
      {:ok, records} -> validate_records(records, expected_count)
      {:error, _reason} -> Error.single([], :invalid_format, "has an invalid ZIP table")
    end
  end

  defp safe_table(archive) do
    :zip.table(archive)
  catch
    _kind, _reason -> {:error, :invalid_archive}
  end

  defp validate_records([comment | files], expected_count) do
    with :ok <- validate_comment(comment),
         :ok <- validate_record_count(files, expected_count),
         {:ok, entries} <- normalize_files(files),
         :ok <- validate_unique_paths(entries),
         :ok <- validate_manifest(entries),
         :ok <- validate_total_size(entries) do
      {:ok, entries}
    end
  end

  defp validate_records(_records, _expected_count) do
    Error.single([], :invalid_format, "has an invalid ZIP table shape")
  end

  defp validate_comment(zip_comment(comment: [])) do
    :ok
  end

  defp validate_comment(_comment) do
    Error.single([], :invalid_format, "archive comments are not supported")
  end

  defp validate_record_count(files, expected_count) do
    record_count_result(length(files) == expected_count)
  end

  defp record_count_result(true) do
    :ok
  end

  defp record_count_result(false) do
    Error.single([], :invalid_format, "central-directory entry count does not match the table")
  end

  defp normalize_files(files) do
    files
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, &normalize_file/2)
    |> reverse_entries()
  end

  defp normalize_file({record, index}, {:ok, entries}) do
    case record do
      zip_file(name: archive_name, info: info, comment: comment, comp_size: compressed_size) ->
        normalize_zip_file(archive_name, info, comment, compressed_size, index, entries)

      _record ->
        {:halt, Error.single([:entries, index], :invalid_format, "has an invalid table entry")}
    end
  end

  defp normalize_zip_file(archive_name, info, comment, compressed_size, index, entries) do
    size = file_info(info, :size)
    type = file_info(info, :type)

    case Draught.Conversation.Interchange.Bundle.Decoder.Entry.new(
           archive_name,
           type,
           size,
           compressed_size,
           comment,
           index
         ) do
      {:ok, entry} -> {:cont, {:ok, [entry | entries]}}
      {:error, %Error{}} = result -> {:halt, result}
    end
  end

  defp validate_unique_paths(entries) do
    entries
    |> Enum.with_index()
    |> Enum.reduce_while(MapSet.new(), fn {entry, index}, seen ->
      normalized = String.downcase(entry.path)
      unique_entry_result(MapSet.member?(seen, normalized), seen, normalized, index)
    end)
    |> unique_result()
  end

  defp unique_entry_result(true, _seen, _normalized, index) do
    {:halt,
     Error.single(
       [:entries, index, :path],
       :duplicate_key,
       "must be unique regardless of case"
     )}
  end

  defp unique_entry_result(false, seen, normalized, _index) do
    {:cont, MapSet.put(seen, normalized)}
  end

  defp unique_result(%MapSet{}) do
    :ok
  end

  defp unique_result({:error, %Error{}} = result) do
    result
  end

  defp validate_manifest(entries) do
    entries
    |> Enum.count(&(&1.kind == :manifest))
    |> manifest_count_result()
  end

  defp manifest_count_result(1) do
    :ok
  end

  defp manifest_count_result(0) do
    Error.single([:entries], :required, "must contain conversation.lmml")
  end

  defp manifest_count_result(_count) do
    Error.single([:entries], :duplicate_key, "must contain conversation.lmml only once")
  end

  defp validate_total_size(entries) do
    entries
    |> Enum.reduce(0, &(&1.size + &2))
    |> total_size_result()
  end

  defp total_size_result(total) when total <= @maximum_total_bytes do
    :ok
  end

  defp total_size_result(_total) do
    Error.single([:entries], :too_large, "uncompressed entries exceed the bundle limit")
  end

  defp reverse_entries({:ok, entries}) do
    {:ok, Enum.reverse(entries)}
  end

  defp reverse_entries({:error, %Error{}} = result) do
    result
  end
end
