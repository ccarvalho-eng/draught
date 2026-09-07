defmodule Draught.Tool.Builtin.ListDirectory.Executor do
  @moduledoc """
  Executes bounded directory listings inside the configured workspace.

  Paths pass through workspace resolution, symbolic-link policy is inherited
  from that boundary, and output is sorted after enforcing an entry limit.
  """

  @behaviour Draught.Tool.Executor

  alias Draught.Tool.Builtin.Failure
  alias Draught.Tool.Call
  alias Draught.Tool.Execution.Context
  alias Draught.Validation.Error
  alias Draught.Workspace.Path.Resolver

  @maximum_entries 1_000

  @impl Draught.Tool.Executor
  def execute(%Call{arguments: %{"path" => relative}}, %Context{} = context, _configuration) do
    with {:ok, path} <- Resolver.resolve(context.workspace, relative, :read),
         {:ok, entries} <- File.ls(path),
         :ok <- validate_entries(entries) do
      entries
      |> Enum.sort()
      |> Enum.join("\n")
      |> then(&{:ok, &1})
    else
      {:error, %Error{}} -> Failure.invalid_path()
      _failure -> Failure.list_failed()
    end
  end

  defp validate_entries(entries) do
    entries
    |> valid_entries?()
    |> entries_result()
  end

  defp valid_entries?(entries) do
    length(entries) <= @maximum_entries and Enum.all?(entries, &String.valid?/1)
  end

  defp entries_result(true) do
    :ok
  end

  defp entries_result(false) do
    :error
  end
end
