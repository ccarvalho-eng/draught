defmodule Draught.Workspace.Path.Boundary do
  @moduledoc """
  Compares absolute path components for workspace containment.
  """

  @doc "Returns whether a candidate is the root or a descendant of it."
  @spec within?(String.t(), String.t()) :: boolean()
  def within?(root, candidate) when is_binary(root) and is_binary(candidate) do
    root
    |> absolute_pair?(candidate)
    |> within_result(root, candidate)
  end

  def within?(_root, _candidate) do
    false
  end

  defp absolute_pair?(root, candidate) do
    Path.type(root) == :absolute and Path.type(candidate) == :absolute
  end

  defp within_result(true, root, candidate) do
    root_components = components(root)
    candidate_components = components(candidate)

    Enum.take(candidate_components, length(root_components)) == root_components
  end

  defp within_result(false, _root, _candidate) do
    false
  end

  defp components(path) do
    path
    |> Path.expand()
    |> Path.split()
  end
end
