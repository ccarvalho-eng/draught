defmodule Draught.CLI.Session.Store.Paths do
  @moduledoc """
  Derives validated persistent-session paths from a workspace identity and user state directory.
  """

  alias Draught.Session.Identifier
  alias Draught.Validation.Error
  alias Draught.Workspace.Filesystem.Local
  alias Draught.Workspace.Path.Canonical
  alias Draught.Workspace.Path.Resolver

  @filesystem {Local, nil}

  @enforce_keys [
    :binding,
    :checkpoint,
    :journal,
    :key,
    :marker,
    :root,
    :session,
    :workspace
  ]
  defstruct [
    :binding,
    :checkpoint,
    :journal,
    :key,
    :marker,
    :root,
    :session,
    :workspace
  ]

  @type t :: %__MODULE__{
          binding: String.t(),
          checkpoint: String.t(),
          journal: String.t(),
          key: String.t(),
          marker: String.t(),
          root: String.t(),
          session: String.t(),
          workspace: String.t()
        }

  @doc "Builds trusted user-state paths for one canonical workspace and session."
  @spec new(term(), term(), term()) :: Error.result(t())
  def new(workspace, identifier, environment) when is_map(environment) do
    with {:ok, id} <- Identifier.new(identifier),
         {:ok, canonical_workspace} <- Resolver.resolve(workspace, ".", :read),
         {:ok, state_home} <- state_home(environment),
         {:ok, canonical_state_home} <- canonical_state_home(state_home) do
      build(canonical_workspace, id, canonical_state_home)
    end
  end

  def new(_workspace, _identifier, _environment) do
    Error.single([:environment], :invalid_type, "must be a map")
  end

  defp build(canonical_workspace, id, state_home) do
    workspace_digest = digest(canonical_workspace)
    root = Path.join(state_home, "draught")
    workspace = Path.join([root, "workspaces", workspace_digest])
    session = Path.join([workspace, "sessions", id])
    key = digest(root <> <<0>> <> workspace_digest <> ":" <> id)

    {:ok,
     %__MODULE__{
       binding: Path.join(session, "binding.json"),
       checkpoint: Path.join(session, "checkpoint.json"),
       journal: Path.join(session, "journal.jsonl"),
       key: key,
       marker: Path.join(session, ".draught-session"),
       root: root,
       session: session,
       workspace: workspace
     }}
  end

  defp state_home(environment) do
    case absolute_path(Map.get(environment, "XDG_STATE_HOME")) do
      {:ok, path} -> {:ok, path}
      :error -> home_state(environment)
    end
  end

  defp canonical_state_home(path) do
    case Canonical.resolve(@filesystem, path, :write) do
      {:ok, canonical} ->
        {:ok, canonical}

      {:error, _reason} ->
        Error.single([:state_home], :invalid_value, "cannot be resolved safely")
    end
  end

  defp home_state(environment) do
    case absolute_path(Map.get(environment, "HOME")) do
      {:ok, home} -> {:ok, Path.join([home, ".local", "state"])}
      :error -> Error.single([:state_home], :required, "requires XDG_STATE_HOME or HOME")
    end
  end

  defp absolute_path(path) when is_binary(path) and byte_size(path) > 0 do
    path
    |> Path.type()
    |> absolute_path_result(path)
  end

  defp absolute_path(_path) do
    :error
  end

  defp absolute_path_result(:absolute, path) do
    {:ok, Path.expand(path)}
  end

  defp absolute_path_result(_type, _path) do
    :error
  end

  defp digest(value) do
    :sha256
    |> :crypto.hash(value)
    |> Base.encode16(case: :lower)
  end
end
