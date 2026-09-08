defmodule Draught.Tool.Builtin.ReplaceInFile.Executor do
  @moduledoc """
  Executes approved, serialized text replacement inside the workspace.

  Approval precedes path resolution and mutation. The resolved operation is
  submitted to the mutation queue so writes do not overlap.
  """

  @behaviour Draught.Tool.Executor

  alias Draught.Tool.Builtin.Failure
  alias Draught.Tool.Builtin.ReplaceInFile.Approval
  alias Draught.Tool.Builtin.ReplaceInFile.Operation
  alias Draught.Tool.Call
  alias Draught.Tool.Execution.Context
  alias Draught.Tool.Mutation.Queue
  alias Draught.Validation.Error
  alias Draught.Workspace.Path.Resolver

  @impl Draught.Tool.Executor
  def execute(%Call{} = call, %Context{} = context, _configuration) do
    arguments = call.arguments
    path = arguments["path"]

    with :ok <- Approval.authorize(call, context),
         {:ok, canonical_path} <- Resolver.resolve(context.workspace, path, :read) do
      Queue.run(Operation, %{
        path: canonical_path,
        expected: arguments["expected"],
        replacement: arguments["replacement"]
      })
    else
      {:error, %Error{}} -> Failure.invalid_path()
      {:error, _error} = result -> result
    end
  end
end
