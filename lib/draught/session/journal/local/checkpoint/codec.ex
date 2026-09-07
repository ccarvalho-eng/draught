defmodule Draught.Session.Journal.Local.Checkpoint.Codec do
  @moduledoc """
  Encodes replay state and journal identity into the versioned checkpoint representation.
  """

  alias Draught.Session.Journal.Failure
  alias Draught.Session.Journal.Local.Checkpoint.Identity
  alias Draught.Session.Journal.Local.Checkpoint.Snapshot
  alias Draught.Session.Journal.Replay
  alias Draught.Session.Journal.Retention

  @schema_version 1

  @doc "Encodes a disposable replay snapshot and its journal identity."
  @spec encode(binary(), Replay.t()) ::
          {:ok, binary()} | {:error, Draught.Error.Normalized.t()}
  def encode(journal, %Replay{} = replay) do
    with {:ok, retention} <- Retention.new(tool_arguments: :retain, tool_output: :retain),
         checkpoint = checkpoint(journal, replay, retention),
         {:ok, encoded} <- Jason.encode(checkpoint) do
      {:ok, encoded}
    else
      _result -> {:error, Failure.io()}
    end
  end

  defp checkpoint(journal, replay, retention) do
    journal
    |> Identity.encode()
    |> Map.put("replay", Snapshot.encode(replay, retention))
    |> Map.put("schema_version", @schema_version)
  end
end
