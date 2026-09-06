defmodule Draught.Workspace.Path.Resolver do
  @moduledoc """
  Resolves paths through lexical and filesystem-aware confinement checks.
  """

  alias Draught.Validation.Error
  alias Draught.Workspace.Filesystem.Local
  alias Draught.Workspace.Path.Boundary
  alias Draught.Workspace.Path.Canonical
  alias Draught.Workspace.Path.Lexical

  @filesystem {Local, nil}

  @doc "Resolves a read or write path inside an existing directory workspace."
  @spec resolve(term(), term(), term()) :: Error.result(String.t())
  def resolve(workspace, path, access) do
    with :ok <- access(access),
         {:ok, lexical_root} <- Lexical.resolve(workspace, "."),
         {:ok, canonical_root} <- workspace(lexical_root),
         {:ok, lexical_target} <- Lexical.resolve(workspace, path),
         {:ok, canonical_target} <- target(lexical_target, access),
         true <- Boundary.within?(canonical_root, canonical_target) do
      {:ok, canonical_target}
    else
      false -> Error.single([:path], :invalid_value, "resolves outside the workspace")
      {:error, %Error{}} = result -> result
    end
  end

  defp access(access) when access in [:read, :write] do
    :ok
  end

  defp access(_access) do
    Error.single([:access], :invalid_value, "must be read or write")
  end

  defp workspace(path) do
    with {:ok, canonical} <- Canonical.resolve(@filesystem, path, :read),
         true <- Canonical.directory?(@filesystem, canonical) do
      {:ok, canonical}
    else
      _result -> Error.single([:workspace], :invalid_value, "must be an existing directory")
    end
  end

  defp target(path, access) do
    case Canonical.resolve(@filesystem, path, access) do
      {:ok, canonical} ->
        {:ok, canonical}

      {:error, :not_found} ->
        Error.single([:path], :invalid_value, "does not exist")

      {:error, :unresolvable} ->
        Error.single([:path], :invalid_value, "cannot be resolved safely")
    end
  end
end
