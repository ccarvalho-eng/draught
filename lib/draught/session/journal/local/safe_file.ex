defmodule Draught.Session.Journal.Local.SafeFile do
  @moduledoc """
  Performs descriptor-verified, bounded access to owner-only regular journal files.

  Path metadata must match the opened descriptor so symlinks and replacement races fail without reading or writing an unexpected target.
  """

  import Bitwise

  @mode 0o600

  @type error :: :io | :missing | :too_large | :unsafe

  @doc "Reads at most the requested bytes from one owner-only regular file."
  @spec read(String.t(), pos_integer()) :: {:ok, binary()} | {:error, error()}
  def read(path, maximum_bytes) do
    with {:ok, expected} <- existing(path, maximum_bytes),
         {:ok, device} <- File.open(path, [:read, :binary]) do
      read_open(device, expected, maximum_bytes)
    end
  end

  @doc "Appends synchronized bytes without exceeding the configured total size."
  @spec append(String.t(), iodata(), pos_integer()) :: :ok | {:error, error()}
  def append(path, content, maximum_bytes) do
    bytes = IO.iodata_length(content)

    case File.lstat(path) do
      {:error, :enoent} ->
        create(path, content, bytes, maximum_bytes)

      {:ok, %File.Stat{} = expected} ->
        append_existing(path, expected, content, bytes, maximum_bytes)

      {:error, _reason} ->
        {:error, :io}
    end
  end

  defp existing(path, maximum_bytes) do
    case File.lstat(path) do
      {:ok, %File.Stat{type: :regular, mode: mode, size: size} = stat}
      when band(mode, 0o777) == @mode and size <= maximum_bytes ->
        {:ok, stat}

      {:ok, %File.Stat{type: :regular, size: size}} when size > maximum_bytes ->
        {:error, :too_large}

      {:ok, %File.Stat{}} ->
        {:error, :unsafe}

      {:error, :enoent} ->
        {:error, :missing}

      {:error, _reason} ->
        {:error, :io}
    end
  end

  defp read_open(device, expected, maximum_bytes) do
    result =
      with {:ok, actual} <- device_stat(device),
           :ok <- same_file(expected, actual),
           content <- IO.binread(device, maximum_bytes + 1) do
        read_result(content, maximum_bytes)
      else
        _result -> {:error, :io}
      end

    result
  after
    File.close(device)
  end

  defp read_result(:eof, _maximum_bytes) do
    {:ok, ""}
  end

  defp read_result(content, maximum_bytes)
       when is_binary(content) and byte_size(content) <= maximum_bytes do
    {:ok, content}
  end

  defp read_result(_content, _maximum_bytes) do
    {:error, :too_large}
  end

  defp create(_path, _content, bytes, maximum_bytes) when bytes > maximum_bytes do
    {:error, :too_large}
  end

  defp create(path, content, _bytes, maximum_bytes) do
    case File.open(path, [:write, :binary, :exclusive]) do
      {:ok, device} -> write_new(device, path, content)
      {:error, :eexist} -> append(path, content, maximum_bytes)
      {:error, _reason} -> {:error, :io}
    end
  end

  defp write_new(device, path, content) do
    result =
      with :ok <- File.chmod(path, @mode),
           {:ok, stat} <- device_stat(device),
           :ok <- safe_new_file(stat),
           :ok <- IO.binwrite(device, content) do
        :file.sync(device)
      else
        _result -> {:error, :io}
      end

    result
  after
    File.close(device)
  end

  defp append_existing(path, expected, content, bytes, maximum_bytes) do
    with :ok <- safe_existing(expected, bytes, maximum_bytes),
         {:ok, device} <- File.open(path, [:append, :binary]) do
      append_open(device, expected, content)
    end
  end

  defp safe_existing(%File.Stat{type: :regular, mode: mode, size: size}, bytes, maximum_bytes)
       when band(mode, 0o777) == @mode and size + bytes <= maximum_bytes do
    :ok
  end

  defp safe_existing(%File.Stat{type: :regular, size: size}, bytes, maximum_bytes)
       when size + bytes > maximum_bytes do
    {:error, :too_large}
  end

  defp safe_existing(%File.Stat{}, _bytes, _maximum_bytes) do
    {:error, :unsafe}
  end

  defp append_open(device, expected, content) do
    result =
      with {:ok, actual} <- device_stat(device),
           :ok <- same_file(expected, actual),
           :ok <- IO.binwrite(device, content) do
        :file.sync(device)
      else
        _result -> {:error, :io}
      end

    result
  after
    File.close(device)
  end

  defp safe_new_file(%File.Stat{type: :regular, mode: mode})
       when band(mode, 0o777) == @mode do
    :ok
  end

  defp safe_new_file(%File.Stat{}) do
    {:error, :unsafe}
  end

  defp device_stat(device) do
    case :file.read_file_info(device) do
      {:ok, record} -> {:ok, File.Stat.from_record(record)}
      {:error, _reason} -> {:error, :io}
    end
  end

  defp same_file(
         %File.Stat{
           type: :regular,
           inode: inode,
           major_device: major,
           minor_device: minor,
           size: size
         },
         %File.Stat{
           type: :regular,
           inode: inode,
           major_device: major,
           minor_device: minor,
           size: size,
           mode: mode
         }
       )
       when band(mode, 0o777) == @mode do
    :ok
  end

  defp same_file(%File.Stat{}, %File.Stat{}) do
    {:error, :unsafe}
  end
end
