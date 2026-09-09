defmodule Draught.Skill.Repository.Local.File do
  @moduledoc """
  Performs bounded non-symlink reads for the local skill repository.

  File identity is rechecked after opening so a replaced entry fails closed.
  """

  alias Draught.Filesystem.OpenFile

  @doc "Lists at most the configured number of direct root entries."
  @spec entries(String.t(), pos_integer()) :: {:ok, [String.t()]} | {:error, atom()}
  def entries(path, maximum) when is_binary(path) and is_integer(maximum) and maximum > 0 do
    case File.lstat(path) do
      {:ok, %File.Stat{type: :directory}} -> list(path, maximum)
      {:ok, %File.Stat{}} -> {:error, :unsafe_root}
      {:error, :enoent} -> {:ok, []}
      {:error, _reason} -> {:error, :io}
    end
  end

  @doc "Checks that one discovered entry is a real directory, not a link."
  @spec directory?(String.t()) :: boolean()
  def directory?(path) when is_binary(path) do
    match?({:ok, %File.Stat{type: :directory}}, File.lstat(path))
  end

  @doc "Reads a bounded prefix after validating the complete file size."
  @spec prefix(String.t(), pos_integer(), pos_integer()) ::
          {:ok, binary()} | {:error, atom()}
  def prefix(path, maximum_file_bytes, maximum_prefix_bytes) do
    read(path, maximum_file_bytes, maximum_prefix_bytes)
  end

  @doc "Reads a complete bounded regular file."
  @spec complete(String.t(), pos_integer()) :: {:ok, binary()} | {:error, atom()}
  def complete(path, maximum_bytes) do
    path
    |> read(maximum_bytes, maximum_bytes + 1)
    |> complete_result(maximum_bytes)
  end

  defp list(path, maximum) do
    case File.ls(path) do
      {:ok, entries} -> bounded_entries(entries, maximum)
      {:error, _reason} -> {:error, :io}
    end
  end

  defp bounded_entries(entries, maximum) do
    entries
    |> Enum.take(maximum + 1)
    |> bounded_entries_result(maximum)
  end

  defp bounded_entries_result(entries, maximum) do
    entries
    |> Enum.split(maximum)
    |> bounded_entries_result()
  end

  defp bounded_entries_result({entries, []}) do
    {:ok, Enum.sort(entries)}
  end

  defp bounded_entries_result({_entries, _overflow}) do
    {:error, :too_many_entries}
  end

  defp read(path, maximum_file_bytes, read_bytes) do
    case File.lstat(path) do
      {:ok, %File.Stat{type: :regular, size: size} = stat} when size <= maximum_file_bytes ->
        open(path, read_bytes, stat)

      {:ok, %File.Stat{type: :regular}} ->
        {:error, :too_large}

      {:ok, %File.Stat{}} ->
        {:error, :unsafe_file}

      {:error, :enoent} ->
        {:error, :missing}

      {:error, _reason} ->
        {:error, :io}
    end
  end

  defp open(path, read_bytes, stat) do
    result =
      File.open(path, [:read, :binary], fn file ->
        with :ok <- OpenFile.verify(file, stat) do
          read_content(file, read_bytes)
        end
      end)

    open_result(result)
  end

  defp read_content(file, read_bytes) do
    case IO.binread(file, read_bytes) do
      :eof -> {:ok, ""}
      {:error, _reason} -> {:error, :io}
      content when is_binary(content) -> {:ok, content}
    end
  end

  defp complete_result({:ok, content}, maximum_bytes)
       when byte_size(content) <= maximum_bytes do
    {:ok, content}
  end

  defp complete_result({:ok, _content}, _maximum_bytes) do
    {:error, :too_large}
  end

  defp complete_result({:error, _reason} = error, _maximum_bytes) do
    error
  end

  defp open_result({:ok, {:ok, content}}) do
    {:ok, content}
  end

  defp open_result({:ok, {:error, reason}}) do
    {:error, reason}
  end

  defp open_result({:error, _reason}) do
    {:error, :io}
  end
end
