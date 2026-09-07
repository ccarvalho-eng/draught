defmodule Draught.Session.Journal.Local.Append do
  @moduledoc false

  alias Draught.Session.Journal.Failure
  alias Draught.Session.Journal.Local.Limits
  alias Draught.Session.Journal.Local.SafeFile

  @record_bytes Limits.record_bytes()

  @doc "Appends, synchronizes, and closes one complete JSONL record."
  @spec write(String.t(), binary()) :: :ok | {:error, Draught.Error.Normalized.t()}
  def write(path, line) do
    with :ok <- record_size(line),
         :ok <- mkdir(path),
         :ok <- SafeFile.append(path, [line, "\n"], Limits.journal_bytes()) do
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

  defp record_size(line) when byte_size(line) <= @record_bytes do
    :ok
  end

  defp record_size(_line) do
    {:error, Failure.io()}
  end
end
