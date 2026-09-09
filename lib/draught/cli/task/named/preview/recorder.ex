defmodule Draught.CLI.Task.Named.Preview.Recorder do
  @moduledoc """
  Updates derived session-list previews after successful durable task turns.

  Preview persistence is best-effort and never changes the authoritative task
  result. The named-session lease remains held while this update runs.
  """

  alias Draught.CLI.Session.Catalog.Preview
  alias Draught.CLI.Session.Catalog.Preview.Local
  alias Draught.CLI.Session.Store.Paths
  alias Draught.Provider.Response

  @doc "Records a successful prompt preview and preserves the observed task result."
  @spec record(
          {Draught.CLI.Task.result(), Draught.CLI.Task.Stream.t()},
          Paths.t(),
          String.t()
        ) :: {Draught.CLI.Task.result(), Draught.CLI.Task.Stream.t()}
  def record({{:ok, %Response{}}, _stream} = observation, %Paths{} = paths, prompt) do
    identifier = Path.basename(paths.session)

    with {:ok, preview} <- Preview.new(identifier, prompt),
         :ok <- Local.put(paths, preview) do
      observation
    else
      _result -> observation
    end
  end

  def record(observation, %Paths{}, _prompt) do
    observation
  end
end
