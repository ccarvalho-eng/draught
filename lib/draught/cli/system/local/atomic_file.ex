defmodule Draught.CLI.System.Local.AtomicFile do
  @moduledoc """
  Publishes owner-only CLI files through a synchronized same-directory replacement.

  The destination must be absent or a regular file. Temporary artifacts are
  exclusive, bounded by the caller, and removed after every outcome.
  """

  alias Draught.CLI.Storage.Directory

  @file_mode 0o600
  @directory_mode 0o700

  @type error :: :io | :publication_unknown | :unsafe_file

  @doc "Atomically replaces an absent or regular destination with owner-only content."
  @spec write(String.t(), binary()) :: :ok | {:error, error()}
  def write(path, content) when is_binary(path) and is_binary(content) do
    temporary = temporary_path(path)

    try do
      with :ok <- ensure_target(path),
           :ok <- ensure_directory(path),
           {:ok, device} <- File.open(temporary, [:write, :binary, :exclusive]),
           :ok <- write_open(device, temporary, content),
           :ok <- ensure_target(path),
           :ok <- publish(temporary, path) do
        Directory.sync_parent(path)
      else
        {:error, :unsafe_file} = result -> result
        _result -> {:error, :io}
      end
    after
      File.rm(temporary)
    end
  end

  defp ensure_target(path) do
    case File.lstat(path) do
      {:ok, %File.Stat{type: :regular}} -> :ok
      {:ok, %File.Stat{}} -> {:error, :unsafe_file}
      {:error, :enoent} -> :ok
      {:error, _reason} -> {:error, :io}
    end
  end

  defp ensure_directory(path) do
    directory = Path.dirname(path)

    with :ok <- File.mkdir_p(directory) do
      File.chmod(directory, @directory_mode)
    end
  end

  defp write_open(device, temporary, content) do
    with :ok <- File.chmod(temporary, @file_mode),
         :ok <- IO.binwrite(device, content) do
      :file.sync(device)
    end
  after
    File.close(device)
  end

  defp publish(temporary, path) do
    case File.rename(temporary, path) do
      :ok -> :ok
      {:error, _reason} -> {:error, :io}
    end
  end

  defp temporary_path(path) do
    token =
      12
      |> :crypto.strong_rand_bytes()
      |> Base.url_encode64(padding: false)

    path
    |> Path.dirname()
    |> Path.join(".config-#{token}.tmp")
  end
end
