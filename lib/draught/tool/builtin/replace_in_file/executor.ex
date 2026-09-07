defmodule Draught.Tool.Builtin.ReplaceInFile.Executor do
  @moduledoc false

  @behaviour Draught.Tool.Executor

  alias Draught.Tool.Builtin.Approval
  alias Draught.Tool.Builtin.Failure
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
    summary = summary(arguments)

    with :ok <- Approval.authorize(call, context, :write, path, summary),
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

  defp summary(arguments) do
    expected_bytes = byte_size(arguments["expected"])
    replacement_bytes = byte_size(arguments["replacement"])
    "path; expected: #{expected_bytes} bytes; replacement: #{replacement_bytes} bytes"
  end
end
