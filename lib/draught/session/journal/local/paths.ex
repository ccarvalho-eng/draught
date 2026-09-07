defmodule Draught.Session.Journal.Local.Paths do
  @moduledoc """
  Resolves workspace-confined journal paths or constructs them inside an already trusted directory.
  """

  alias Draught.Session.Identifier
  alias Draught.Validation.Error
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

  @doc "Builds local-journal paths inside an already trusted absolute directory."
  @spec from_directory(term(), term()) :: Error.result(t())
  def from_directory(identifier, directory) when is_binary(directory) do
    with {:ok, id} <- Identifier.new(identifier),
         :ok <- absolute_directory(directory) do
      {:ok,
       %__MODULE__{
         checkpoint: Path.join(directory, "checkpoint.json"),
         directory: directory,
         id: id,
         journal: Path.join(directory, "journal.jsonl")
       }}
    end
  end

  def from_directory(identifier, _directory) do
    with {:ok, _id} <- Identifier.new(identifier) do
      Error.single([:directory], :invalid_type, "must be an absolute path")
    end
  end

  defp absolute_directory(directory) do
    valid = directory != "" and Path.type(directory) == :absolute

    absolute_directory_result(valid)
  end

  defp absolute_directory_result(true) do
    :ok
  end

  defp absolute_directory_result(false) do
    Error.single([:directory], :invalid_value, "must be an absolute path")
  end
end
