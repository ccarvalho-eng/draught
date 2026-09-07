defmodule Draught.Session.Journal.Local.Checkpoint do
  @moduledoc false

  alias Draught.Session.Journal.Failure
  alias Draught.Session.Journal.Local.AtomicFile
  alias Draught.Session.Journal.Local.Checkpoint.Codec
  alias Draught.Session.Journal.Replay

  @doc "Writes a disposable replay snapshot with journal identity metadata."
  @spec write(String.t(), String.t(), Replay.t()) ::
          :ok | {:error, Draught.Error.Normalized.t()}
  def write(path, journal_path, %Replay{} = replay) do
    with {:ok, journal} <- read_journal(journal_path),
         {:ok, encoded} <- Codec.encode(journal, replay) do
      AtomicFile.write(path, encoded)
    else
      _result -> {:error, Failure.io()}
    end
  end

  defp read_journal(path) do
    case File.read(path) do
      {:ok, content} -> {:ok, content}
      {:error, :enoent} -> {:ok, ""}
      {:error, _reason} -> {:error, Failure.io()}
    end
  end
end
