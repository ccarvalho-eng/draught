defmodule Draught.Session.LocalJournal do
  @moduledoc false

  alias Draught.Session.Journal
  alias Draught.Session.Journal.Local
  alias Draught.Session.Journal.Local.Configuration
  alias Draught.Session.Journal.Replay

  @doc "Replays one default workspace-local journal."
  @spec replay(term(), term(), map() | keyword()) ::
          {:ok, Replay.t()} | {:error, Journal.error()}
  def replay(workspace, identifier, options) do
    with {:ok, configuration} <- Configuration.new(workspace, identifier, options) do
      Journal.replay({Local, configuration})
    end
  end
end
