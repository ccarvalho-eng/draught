defmodule Draught.Session.Journal.Local.AtomicFile do
  @moduledoc false

  alias Draught.Session.Journal.Failure

  @doc "Writes and synchronizes a same-directory temporary file before atomic rename."
  @spec write(String.t(), binary()) :: :ok | {:error, Draught.Error.Normalized.t()}
  def write(path, content) do
    temporary = temporary_path(path)

    try do
      with :ok <- mkdir(path),
           {:ok, device} <- File.open(temporary, [:write, :binary, :exclusive]),
           :ok <- write_open(device, temporary, content),
           :ok <- File.rename(temporary, path) do
        :ok
      else
        _result -> {:error, Failure.io()}
      end
    after
      File.rm(temporary)
    end
  end

  defp mkdir(path) do
    directory = Path.dirname(path)

    with :ok <- File.mkdir_p(directory) do
      File.chmod(directory, 0o700)
    end
  end

  defp write_open(device, path, content) do
    with :ok <- File.chmod(path, 0o600),
         :ok <- IO.binwrite(device, content) do
      :file.sync(device)
    end
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
    |> Path.join("checkpoint-#{token}.tmp")
  end
end
