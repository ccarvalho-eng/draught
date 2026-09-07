defmodule Draught.Conversation.Interchange.Bundle.Decoder.Extractor do
  @moduledoc false

  alias Draught.Conversation.Interchange.Bundle.Entry
  alias Draught.Validation.Error

  @doc "Selectively extracts only previously validated entries into memory."
  @spec extract(binary(), [Entry.t()]) :: Error.result(%{String.t() => binary()})
  def extract(_archive, []) do
    {:ok, %{}}
  end

  def extract(archive, entries) do
    archive_names = Enum.map(entries, & &1.archive_name)

    case safe_extract(archive, archive_names) do
      {:ok, files} ->
        validate_files(files, entries)

      {:error, _reason} ->
        Error.single([], :invalid_format, "could not extract validated entries")
    end
  end

  defp safe_extract(archive, archive_names) do
    :zip.extract(archive, [:memory, {:file_list, archive_names}])
  catch
    _kind, _reason -> {:error, :invalid_archive}
  end

  defp validate_files(files, entries) do
    validate_file_count(files, entries, length(files) == length(entries))
  end

  defp validate_file_count(files, entries, true) do
    expected = Map.new(entries, &{&1.path, &1.size})

    files
    |> Enum.reduce_while({:ok, %{}}, &validate_file(&1, &2, expected))
    |> validate_complete(expected)
  end

  defp validate_file_count(_files, _entries, false) do
    Error.single([], :invalid_format, "extracted entry count does not match the table")
  end

  defp validate_file({name, content}, {:ok, extracted}, expected)
       when is_list(name) and is_binary(content) do
    path = List.to_string(name)

    case Map.fetch(expected, path) do
      {:ok, size} when byte_size(content) == size ->
        {:cont, {:ok, Map.put(extracted, path, content)}}

      _missing_or_mismatch ->
        {:halt, Error.single([:entries, path], :invalid_format, "does not match the ZIP table")}
    end
  end

  defp validate_file(_file, _result, _expected) do
    {:halt, Error.single([:entries], :invalid_format, "has an invalid extracted entry")}
  end

  defp validate_complete({:ok, extracted}, expected)
       when map_size(extracted) == map_size(expected) do
    {:ok, extracted}
  end

  defp validate_complete({:ok, _extracted}, _expected) do
    Error.single([:entries], :invalid_format, "did not extract every validated entry")
  end

  defp validate_complete({:error, %Error{}} = result, _expected) do
    result
  end
end
