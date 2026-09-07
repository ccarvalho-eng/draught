defmodule Draught.Session.Journal.Local.Append do
  @moduledoc false

  alias Draught.Session.Journal.Failure

  @doc "Appends, synchronizes, and closes one complete JSONL record."
  @spec write(String.t(), binary()) :: :ok | {:error, Draught.Error.Normalized.t()}
  def write(path, line) do
    with :ok <- mkdir(path),
         {:ok, device} <- File.open(path, [:append, :binary]),
         :ok <- write_open(device, path, line) do
      :ok
    else
      _result -> {:error, Failure.io()}
    end
  end

  defp mkdir(path) do
    directory = Path.dirname(path)

    with :ok <- File.mkdir_p(directory) do
      File.chmod(directory, 0o700)
    end
  end

  defp write_open(device, path, line) do
    with :ok <- File.chmod(path, 0o600),
         :ok <- IO.binwrite(device, [line, "\n"]) do
      :file.sync(device)
    end
  after
    File.close(device)
  end
end
