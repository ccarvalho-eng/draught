defmodule Draught.CLI.Task.Named.History do
  @moduledoc """
  Builds, replays, and attaches the full-retention journal for a named CLI task.
  """

  alias Draught.CLI.Session.Store
  alias Draught.CLI.Task.Preparation
  alias Draught.Session.Journal
  alias Draught.Session.Journal.Local
  alias Draught.Session.Journal.Local.Configuration

  @retention [tool_arguments: :retain, tool_output: :retain]

  @doc "Builds a full-retention journal within the trusted session directory."
  @spec journal(String.t(), Store.Handle.t()) ::
          {:ok, Journal.adapter()} | {:error, :session, Draught.CLI.Task.error()}
  def journal(identifier, store) do
    case Configuration.from_directory(identifier, store.paths.session, retention: @retention) do
      {:ok, configuration} -> {:ok, {Local, configuration}}
      {:error, error} -> {:error, :session, error}
    end
  end

  @doc "Replays a named journal while categorizing failures."
  @spec replay(Journal.adapter()) ::
          {:ok, Journal.Replay.t()} | {:error, :session, Draught.CLI.Task.error()}
  def replay(journal) do
    case Journal.replay(journal) do
      {:ok, replay} -> {:ok, replay}
      {:error, error} -> {:error, :session, error}
    end
  end

  @doc "Attaches a persistent journal to an immutable preparation."
  @spec attach(Preparation.t(), Journal.adapter()) :: Preparation.t()
  def attach(preparation, journal) do
    options = Keyword.put(preparation.session_options, :journal, journal)
    %{preparation | session_options: options}
  end
end
