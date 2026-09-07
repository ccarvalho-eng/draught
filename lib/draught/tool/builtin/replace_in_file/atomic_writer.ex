defmodule Draught.Tool.Builtin.ReplaceInFile.AtomicWriter do
  @moduledoc false

  import Bitwise, only: [band: 2]

  @doc "Writes a same-directory temporary file and atomically replaces the target."
  @spec write(String.t(), binary()) :: :ok | {:error, term()}
  def write(path, content) do
    temporary = temporary_path(path)
    write_with_cleanup(path, temporary, content)
  end

  defp write_with_cleanup(path, temporary, content) do
    commit(path, temporary, content)
  after
    File.rm(temporary)
  end

  defp commit(path, temporary, content) do
    with {:ok, %File.Stat{mode: mode}} <- File.stat(path),
         :ok <- write_temporary(temporary, content),
         :ok <- File.chmod(temporary, band(mode, 0o777)) do
      File.rename(temporary, path)
    end
  end

  defp write_temporary(path, content) do
    case File.open(path, [:write, :binary, :exclusive]) do
      {:ok, device} -> write_open(device, content)
      {:error, _reason} = result -> result
    end
  end

  defp write_open(device, content) do
    IO.binwrite(device, content)
  after
    File.close(device)
  end

  defp temporary_path(path) do
    token =
      12
      |> :crypto.strong_rand_bytes()
      |> Base.url_encode64(padding: false)

    path
    |> Path.dirname()
    |> Path.join("draught-#{token}.tmp")
  end
end
