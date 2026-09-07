defmodule Draught.Session.Journal.Local.Checkpoint.Snapshot do
  @moduledoc false

  alias Draught.Provider.Usage
  alias Draught.Session.Journal.Codec.Message
  alias Draught.Session.Journal.Codec.Outcome
  alias Draught.Session.Journal.Replay
  alias Draught.Session.Journal.Retention

  @doc "Encodes reconstructed canonical state for a disposable checkpoint."
  @spec encode(Replay.t(), Retention.t()) :: map()
  def encode(%Replay{} = replay, %Retention{} = retention) do
    %{
      "created_at" => timestamp(replay.created_at),
      "id" => replay.id,
      "last_turn_id" => replay.last_turn_id,
      "messages" => Enum.map(replay.messages, &Message.encode(&1, retention)),
      "model" => replay.model,
      "next_sequence" => replay.next_sequence,
      "provider" => replay.provider,
      "terminal" => terminal(replay.terminal, retention),
      "updated_at" => timestamp(replay.updated_at),
      "usage" => usage(replay.usage)
    }
  end

  defp timestamp(nil) do
    nil
  end

  defp timestamp(%DateTime{} = timestamp) do
    DateTime.to_iso8601(timestamp)
  end

  defp terminal(:empty, _retention) do
    %{"state" => "empty"}
  end

  defp terminal({:interrupted, turn_id}, _retention) do
    %{"state" => "interrupted", "turn_id" => turn_id}
  end

  defp terminal({:completed, turn_id, outcome}, retention) do
    %{
      "outcome" => Outcome.encode(outcome, retention),
      "state" => "completed",
      "turn_id" => turn_id
    }
  end

  defp usage(nil) do
    nil
  end

  defp usage(%Usage{} = usage) do
    usage
    |> Map.from_struct()
    |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end)
  end
end
