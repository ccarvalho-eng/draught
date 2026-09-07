defmodule Draught.Session.Journal.Local.Paths do
  @moduledoc false

  alias Draught.Session.Identifier
  alias Draught.Workspace.Path.Resolver

  @enforce_keys [:checkpoint, :directory, :id, :journal]
  defstruct [:checkpoint, :directory, :id, :journal]

  @type t :: %__MODULE__{
          checkpoint: String.t(),
          directory: String.t(),
          id: String.t(),
          journal: String.t()
        }

  @doc "Builds confined local-journal paths after validating the session identifier."
  @spec new(term(), term()) :: Draught.Validation.Error.result(t())
  def new(workspace, identifier) do
    with {:ok, id} <- Identifier.new(identifier),
         relative_directory = Path.join([".draught", "sessions", id]),
         {:ok, directory} <- Resolver.resolve(workspace, relative_directory, :write),
         {:ok, journal} <-
           Resolver.resolve(workspace, Path.join(relative_directory, "journal.jsonl"), :write),
         {:ok, checkpoint} <-
           Resolver.resolve(workspace, Path.join(relative_directory, "checkpoint.json"), :write) do
      {:ok, %__MODULE__{checkpoint: checkpoint, directory: directory, id: id, journal: journal}}
    end
  end
end
