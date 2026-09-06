defmodule Draught.Workspace.Path.Lexical do
  @moduledoc """
  Resolves untrusted relative paths without consulting filesystem state.
  """

  alias Draught.Validation.Error
  alias Draught.Validation.Value
  alias Draught.Workspace.Path.Boundary

  @doc "Resolves a forward-slash relative path against an absolute workspace."
  @spec resolve(term(), term()) :: Error.result(String.t())
  def resolve(workspace, path) do
    with {:ok, root} <- workspace(workspace),
         {:ok, relative} <- relative(path),
         {:ok, safe_relative} <- safe_relative(relative, root),
         candidate = Path.expand(safe_relative, root),
         true <- Boundary.within?(root, candidate) do
      {:ok, candidate}
    else
      false -> Error.single([:path], :invalid_value, "must remain inside the workspace")
      {:error, %Error{}} = result -> result
    end
  end

  defp workspace(value) do
    with {:ok, path} <- Value.string(value, [:workspace]),
         true <- Path.type(path) == :absolute do
      {:ok, Path.expand(path)}
    else
      false -> Error.single([:workspace], :invalid_value, "must be an absolute path")
      {:error, %Error{}} = result -> result
    end
  end

  defp relative(value) do
    with {:ok, path} <- Value.string(value, [:path]),
         :ok <- portable_separators(path),
         :ok <- portable_absolute(path),
         :ok <- relative_type(path),
         :ok <- traversal(path) do
      {:ok, path}
    end
  end

  defp portable_separators(path) do
    path
    |> String.contains?("\\")
    |> separator_result()
  end

  defp separator_result(false) do
    :ok
  end

  defp separator_result(true) do
    Error.single([:path], :invalid_value, "must use forward-slash path separators")
  end

  defp portable_absolute(path) do
    path
    |> then(&Regex.match?(~r/\A[A-Za-z]:/, &1))
    |> portable_absolute_result()
  end

  defp portable_absolute_result(false) do
    :ok
  end

  defp portable_absolute_result(true) do
    Error.single([:path], :invalid_value, "must be relative to the workspace")
  end

  defp relative_type(path) do
    path
    |> Path.type()
    |> relative_type_result()
  end

  defp relative_type_result(:relative) do
    :ok
  end

  defp relative_type_result(_type) do
    Error.single([:path], :invalid_value, "must be relative to the workspace")
  end

  defp traversal(path) do
    path
    |> String.split("/", trim: false)
    |> Enum.member?("..")
    |> traversal_result()
  end

  defp traversal_result(false) do
    :ok
  end

  defp traversal_result(true) do
    Error.single([:path], :invalid_value, "must not contain parent traversal")
  end

  defp safe_relative(path, root) do
    case Path.safe_relative(path, root) do
      {:ok, _relative} -> {:ok, path}
      :error -> Error.single([:path], :invalid_value, "must remain inside the workspace")
    end
  end
end
