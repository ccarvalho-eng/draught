defmodule Draught.Session.Journal.Local do
  @moduledoc """
  Stores a session as append-only, versioned JSONL inside its workspace.
  """

  @behaviour Draught.Session.Journal.Adapter

  alias Draught.Session.Journal.Failure
  alias Draught.Session.Journal.Local.Append
  alias Draught.Session.Journal.Local.Checkpoint
  alias Draught.Session.Journal.Local.Configuration
  alias Draught.Session.Journal.Local.Handle
  alias Draught.Session.Journal.Record
  alias Draught.Session.Journal.Replay.Loader

  @impl Draught.Session.Journal.Adapter
  def open(%Configuration{} = configuration) do
    with {:ok, replay} <- replay(configuration) do
      {:ok, Handle.new(configuration, replay.next_sequence), replay}
    end
  end

  @impl Draught.Session.Journal.Adapter
  def append(%Handle{} = handle, event) do
    with {:ok, timestamp} <- timestamp(handle.configuration.clock),
         record = Record.new(handle.next_sequence, timestamp, event),
         {:ok, encoded} <- Record.encode(record, handle.configuration.retention),
         :ok <- Append.write(handle.configuration.paths.journal, encoded) do
      {:ok, Handle.advance(handle)}
    end
  end

  @impl Draught.Session.Journal.Adapter
  def checkpoint(%Handle{} = handle) do
    paths = handle.configuration.paths

    with {:ok, replay} <- Loader.load(paths.journal, paths.id),
         :ok <- Checkpoint.write(paths.checkpoint, paths.journal, replay) do
      {:ok, handle}
    end
  end

  @impl Draught.Session.Journal.Adapter
  def replay(%Configuration{} = configuration) do
    Loader.load(configuration.paths.journal, configuration.paths.id)
  end

  defp timestamp(clock) do
    case clock.() do
      %DateTime{} = timestamp -> {:ok, timestamp}
      _value -> {:error, Failure.io()}
    end
  end
end
