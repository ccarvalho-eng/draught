defmodule Draught.CLI.System.Local do
  @moduledoc false

  @behaviour Draught.CLI.System.Adapter

  @impl Draught.CLI.System.Adapter
  def cwd(_configuration) do
    case File.cwd() do
      {:ok, path} -> {:ok, path}
      {:error, _reason} -> {:error, :io}
    end
  end

  @impl Draught.CLI.System.Adapter
  def environment(_configuration) do
    System.get_env()
  end

  @impl Draught.CLI.System.Adapter
  def read_file(path, maximum_bytes, _configuration)
      when is_binary(path) and is_integer(maximum_bytes) and maximum_bytes > 0 do
    case File.lstat(path) do
      {:ok, %File.Stat{type: :regular, size: size} = stat} when size <= maximum_bytes ->
        bounded_read(path, maximum_bytes, stat)

      {:ok, %File.Stat{type: :regular}} ->
        {:error, :too_large}

      {:ok, %File.Stat{}} ->
        {:error, :unsafe_file}

      {:error, :enoent} ->
        :missing

      {:error, _reason} ->
        {:error, :io}
    end
  end

  @impl Draught.CLI.System.Adapter
  def workspace(path, _configuration) do
    case File.stat(path) do
      {:ok, %File.Stat{type: :directory, access: :read_write}} ->
        :ok

      {:ok, %File.Stat{type: :directory}} ->
        {:error, :inaccessible}

      {:ok, %File.Stat{}} ->
        {:error, :not_directory}

      {:error, _reason} ->
        {:error, :inaccessible}
    end
  end

  @impl Draught.CLI.System.Adapter
  def write(stream, content, _configuration) do
    stream
    |> device()
    |> IO.write(content)
  rescue
    ErlangError -> {:error, :closed}
  end

  @impl Draught.CLI.System.Adapter
  def tty?(_stream, _configuration) do
    IO.ANSI.enabled?()
  end

  @impl Draught.CLI.System.Adapter
  def columns(_configuration) do
    case :io.columns() do
      {:ok, columns} when is_integer(columns) and columns > 0 -> {:ok, columns}
      _result -> {:error, :unavailable}
    end
  end

  defp bounded_read(path, maximum_bytes, stat) do
    result =
      File.open(path, [:read, :binary], fn file ->
        with :ok <- same_file(file, stat) do
          file
          |> IO.binread(maximum_bytes + 1)
          |> bounded_read_result(maximum_bytes)
        end
      end)

    file_result(result)
  end

  defp bounded_read_result(:eof, _maximum_bytes) do
    {:ok, ""}
  end

  defp bounded_read_result({:error, _reason}, _maximum_bytes) do
    {:error, :io}
  end

  defp bounded_read_result(content, maximum_bytes)
       when is_binary(content) and byte_size(content) <= maximum_bytes do
    {:ok, content}
  end

  defp bounded_read_result(_content, _maximum_bytes) do
    {:error, :too_large}
  end

  defp file_result({:ok, {:ok, _content} = result}) do
    result
  end

  defp file_result({:ok, {:error, reason}})
       when reason in [:io, :too_large, :unsafe_file] do
    {:error, reason}
  end

  defp file_result({:error, _reason}) do
    {:error, :io}
  end

  defp device(:stdout) do
    :stdio
  end

  defp device(:stderr) do
    :stderr
  end

  defp same_file(file, stat) do
    case :file.read_file_info(file) do
      {:ok,
       {:file_info, _size, :regular, _access, _atime, _mtime, _ctime, _mode, _links, major_device,
        minor_device, inode, _uid, _gid}} ->
        same_identity =
          stat.major_device == major_device and stat.minor_device == minor_device and
            stat.inode == inode

        same_file_result(same_identity)

      _result ->
        {:error, :unsafe_file}
    end
  end

  defp same_file_result(true) do
    :ok
  end

  defp same_file_result(false) do
    {:error, :unsafe_file}
  end
end
