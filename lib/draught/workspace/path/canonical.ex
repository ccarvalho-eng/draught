defmodule Draught.Workspace.Path.Canonical do
  @moduledoc false

  @maximum_symlinks 40
  @maximum_link_target_bytes 4_096

  @type access :: :read | :write
  @type adapter :: {module(), term()}
  @type reason :: :not_found | :unresolvable
  @type result :: {:ok, String.t()} | {:error, reason()}

  @doc "Resolves existing components and follows bounded symbolic links."
  @spec resolve(adapter(), String.t(), access()) :: result()
  def resolve(adapter, path, access) when is_binary(path) and access in [:read, :write] do
    path
    |> Path.type()
    |> resolve_type(adapter, path, access)
  end

  def resolve(_adapter, _path, _access) do
    {:error, :unresolvable}
  end

  @doc "Returns whether a resolved path names a directory."
  @spec directory?(adapter(), String.t()) :: boolean()
  def directory?(adapter, path) when is_binary(path) do
    path
    |> Path.type()
    |> directory_type(adapter, path)
  end

  def directory?(_adapter, _path) do
    false
  end

  defp resolve_type(:absolute, adapter, path, access) do
    path
    |> Path.split()
    |> walk_from_root(adapter, access, 0)
  end

  defp resolve_type(_type, _adapter, _path, _access) do
    {:error, :unresolvable}
  end

  defp directory_type(:absolute, {module, configuration}, path) do
    module
    |> then(& &1.lstat(path, configuration))
    |> then(&match?({:ok, %File.Stat{type: :directory}}, &1))
  end

  defp directory_type(_type, _adapter, _path) do
    false
  end

  defp walk_from_root([root | components], adapter, access, followed) do
    walk(adapter, root, components, access, followed)
  end

  defp walk_from_root(_components, _adapter, _access, _followed) do
    {:error, :unresolvable}
  end

  defp walk(_adapter, current, [], _access, _followed) do
    {:ok, current}
  end

  defp walk({module, configuration} = adapter, current, [component | rest], access, followed) do
    candidate = Path.join(current, component)

    case module.lstat(candidate, configuration) do
      {:ok, %File.Stat{type: :symlink}} ->
        follow_link(adapter, candidate, rest, access, followed)

      {:ok, %File.Stat{}} ->
        walk(adapter, candidate, rest, access, followed)

      {:error, :enoent} ->
        missing(current, [component | rest], access)

      {:error, _reason} ->
        {:error, :unresolvable}
    end
  end

  defp follow_link(_adapter, _candidate, _rest, _access, followed)
       when followed >= @maximum_symlinks do
    {:error, :unresolvable}
  end

  defp follow_link({module, configuration} = adapter, candidate, rest, access, followed) do
    with {:ok, target} <- module.read_link(candidate, configuration),
         {:ok, absolute_target} <- absolute_link_target(target, candidate),
         {:ok, resolved_target} <- resolve_existing(adapter, absolute_target, followed + 1) do
      walk(adapter, resolved_target, rest, access, followed + 1)
    else
      _result -> {:error, :unresolvable}
    end
  end

  defp resolve_existing(adapter, path, followed) do
    path
    |> Path.split()
    |> walk_from_root(adapter, :read, followed)
  end

  defp absolute_link_target(target, candidate)
       when is_binary(target) and byte_size(target) <= @maximum_link_target_bytes do
    target
    |> String.valid?()
    |> link_target_result(target, candidate)
  end

  defp absolute_link_target(_target, _candidate) do
    {:error, :unresolvable}
  end

  defp link_target_result(true, target, candidate) do
    absolute =
      candidate
      |> Path.dirname()
      |> then(&Path.expand(target, &1))

    {:ok, absolute}
  end

  defp link_target_result(false, _target, _candidate) do
    {:error, :unresolvable}
  end

  defp missing(_current, _remaining, :read) do
    {:error, :not_found}
  end

  defp missing(current, remaining, :write) do
    {:ok, Enum.reduce(remaining, current, &Path.join(&2, &1))}
  end
end
