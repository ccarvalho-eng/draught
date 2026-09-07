defmodule Draught.Tool.Builtin.SearchWorkspace.Walker do
  @moduledoc false

  @maximum_entries 5_000
  @excluded_directories MapSet.new([".git", "_build", "cover", "deps", "doc", "tmp"])

  @type reason :: :limit_exceeded | :scan_failed
  @type result :: {:ok, [String.t()]} | {:error, reason()}

  @doc "Collects regular files without following symbolic links."
  @spec files(String.t()) :: result()
  def files(root) do
    case File.lstat(root) do
      {:ok, %File.Stat{type: :regular}} ->
        {:ok, [root]}

      {:ok, %File.Stat{type: :directory}} ->
        root
        |> walk(%{entries: 0, files: []})
        |> finalize()

      _result ->
        {:error, :scan_failed}
    end
  end

  defp walk(path, state) do
    case File.ls(path) do
      {:ok, entries} -> walk_entries(path, Enum.sort(entries), state)
      {:error, _reason} -> {:error, :scan_failed}
    end
  end

  defp walk_entries(_path, [], state) do
    {:ok, state}
  end

  defp walk_entries(path, [entry | rest], state) do
    with {:ok, counted} <- count_entry(state),
         {:ok, next} <- inspect_entry(path, entry, counted) do
      walk_entries(path, rest, next)
    end
  end

  defp count_entry(%{entries: entries} = state) when entries < @maximum_entries do
    {:ok, %{state | entries: entries + 1}}
  end

  defp count_entry(_state) do
    {:error, :limit_exceeded}
  end

  defp inspect_entry(path, entry, state) do
    child = Path.join(path, entry)

    case File.lstat(child) do
      {:ok, %File.Stat{type: :regular}} ->
        {:ok, %{state | files: [child | state.files]}}

      {:ok, %File.Stat{type: :directory}} ->
        descend(child, entry, state)

      {:ok, %File.Stat{}} ->
        {:ok, state}

      {:error, _reason} ->
        {:error, :scan_failed}
    end
  end

  defp descend(child, entry, state) do
    @excluded_directories
    |> MapSet.member?(entry)
    |> descend_result(child, state)
  end

  defp descend_result(true, _child, state) do
    {:ok, state}
  end

  defp descend_result(false, child, state) do
    walk(child, state)
  end

  defp finalize({:ok, state}) do
    {:ok, Enum.reverse(state.files)}
  end

  defp finalize({:error, _reason} = result) do
    result
  end
end
