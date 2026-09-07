defmodule Draught.Tool.Builtin.SearchWorkspace.Executor do
  @moduledoc false

  @behaviour Draught.Tool.Executor

  alias Draught.Tool.Builtin.Failure
  alias Draught.Tool.Builtin.SearchWorkspace.Searcher
  alias Draught.Tool.Builtin.SearchWorkspace.Walker
  alias Draught.Tool.Call
  alias Draught.Tool.Execution.Context
  alias Draught.Validation.Error
  alias Draught.Workspace.Path.Resolver

  @maximum_query_bytes 256

  @impl Draught.Tool.Executor
  def execute(%Call{arguments: arguments}, %Context{} = context, _configuration) do
    arguments
    |> search(context)
    |> normalize()
  end

  defp search(arguments, context) do
    with {:ok, query} <- query(arguments),
         {:ok, root} <-
           Resolver.resolve(context.workspace, Map.get(arguments, "path", "."), :read),
         {:ok, files} <- Walker.files(root) do
      Searcher.search(root, files, query, case_sensitive?(arguments))
    end
  end

  defp query(arguments) do
    case Map.fetch(arguments, "query") do
      {:ok, query}
      when is_binary(query) and byte_size(query) > 0 and
             byte_size(query) <= @maximum_query_bytes ->
        {:ok, query}

      _result ->
        {:error, :invalid_query}
    end
  end

  defp case_sensitive?(arguments) do
    Map.get(arguments, "case_sensitive", true)
  end

  defp normalize({:ok, output}) do
    {:ok, output}
  end

  defp normalize({:error, :invalid_query}) do
    Failure.invalid_query()
  end

  defp normalize({:error, %Error{}}) do
    Failure.invalid_path()
  end

  defp normalize({:error, :scan_failed}) do
    Failure.search_failed()
  end

  defp normalize({:error, :limit_exceeded}) do
    Failure.search_limit_exceeded()
  end
end
