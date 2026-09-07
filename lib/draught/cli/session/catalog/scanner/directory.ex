defmodule Draught.CLI.Session.Catalog.Scanner.Directory do
  @moduledoc """
  Validates the existing catalog directory chain without creating or changing it.

  Every application-owned component must be an owner-only directory. Missing
  components represent an empty catalog, while symlinks and other unexpected
  filesystem shapes fail closed.
  """

  import Bitwise

  alias Draught.CLI.Session.Failure
  alias Draught.CLI.Session.Store.Scope

  @owner_mode 0o700

  @doc "Validates the complete application-owned path to the sessions directory."
  @spec validate(Scope.t()) :: :ok | :missing | {:error, term()}
  def validate(%Scope{} = scope) do
    scope
    |> directories()
    |> Enum.reduce_while(:ok, &validate_next/2)
  end

  defp directories(scope) do
    [
      scope.root,
      Path.join(scope.root, "workspaces"),
      scope.workspace,
      scope.sessions
    ]
  end

  defp validate_next(directory, :ok) do
    case File.lstat(directory) do
      {:ok, %File.Stat{type: :directory, mode: mode}} when band(mode, 0o777) == @owner_mode ->
        {:cont, :ok}

      {:ok, %File.Stat{}} ->
        {:halt, {:error, Failure.storage_unsafe()}}

      {:error, :enoent} ->
        {:halt, :missing}

      {:error, _reason} ->
        {:halt, {:error, Failure.storage_unavailable()}}
    end
  end
end
