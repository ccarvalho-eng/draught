defmodule Draught.Tool.Builtin.RunCommand.Executable do
  @moduledoc """
  Resolves an executable without invoking a shell.

  Explicit paths are expanded relative to the workspace; bare names are
  searched only through bounded absolute entries in the controlled path.
  """

  import Bitwise, only: [band: 2]

  @maximum_path_entries 128

  @doc "Resolves an executable against the controlled path or an explicit location."
  @spec resolve(String.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def resolve(name, workspace, search_path) do
    name
    |> candidates(workspace, search_path)
    |> Enum.find(&executable?/1)
    |> result()
  end

  defp candidates(name, workspace, search_path) do
    name
    |> String.contains?("/")
    |> candidates_result(name, workspace, search_path)
  end

  defp path_candidates(name, search_path) do
    search_path
    |> String.split(":", trim: true)
    |> Enum.filter(&(Path.type(&1) == :absolute))
    |> Enum.take(@maximum_path_entries)
    |> Enum.map(&Path.join(&1, name))
  end

  defp executable?(path) do
    case File.stat(path) do
      {:ok, %File.Stat{type: :regular, mode: mode}} -> band(mode, 0o111) > 0
      _result -> false
    end
  end

  defp candidates_result(true, name, workspace, _search_path) do
    [Path.expand(name, workspace)]
  end

  defp candidates_result(false, name, _workspace, search_path) do
    path_candidates(name, search_path)
  end

  defp result(nil) do
    {:error, :not_found}
  end

  defp result(path) do
    {:ok, path}
  end
end
