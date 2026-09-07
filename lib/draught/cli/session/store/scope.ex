defmodule Draught.CLI.Session.Store.Scope do
  @moduledoc """
  Derives the trusted user-state scope shared by every session in one workspace.

  Canonical workspace and state paths ensure aliases resolve to the same
  catalog and lease namespace without exposing the workspace path on disk.
  """

  alias Draught.Validation.Error
  alias Draught.Workspace.Filesystem.Local
  alias Draught.Workspace.Path.Canonical
  alias Draught.Workspace.Path.Resolver

  @filesystem {Local, nil}

  @enforce_keys [:root, :sessions, :workspace]
  defstruct [:root, :sessions, :workspace]

  @type t :: %__MODULE__{
          root: String.t(),
          sessions: String.t(),
          workspace: String.t()
        }

  @doc "Builds the canonical persistent-session scope for one workspace."
  @spec new(term(), term()) :: Error.result(t())
  def new(workspace, environment) when is_map(environment) do
    with {:ok, canonical_workspace} <- Resolver.resolve(workspace, ".", :read),
         {:ok, state_home} <- state_home(environment),
         {:ok, canonical_state_home} <- canonical_state_home(state_home) do
      build(canonical_workspace, canonical_state_home)
    end
  end

  def new(_workspace, _environment) do
    Error.single([:environment], :invalid_type, "must be a map")
  end

  defp build(canonical_workspace, state_home) do
    root = Path.join(state_home, "draught")
    workspace = Path.join([root, "workspaces", digest(canonical_workspace)])

    {:ok,
     %__MODULE__{
       root: root,
       sessions: Path.join(workspace, "sessions"),
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
