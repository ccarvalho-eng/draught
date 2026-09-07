defmodule Draught.Tool.Builtin.ReadFile.Executor do
  @moduledoc false

  @behaviour Draught.Tool.Executor

  alias Draught.Tool.Builtin.Failure
  alias Draught.Tool.Builtin.ReadFile.Reader
  alias Draught.Tool.Call
  alias Draught.Tool.Execution.Context
  alias Draught.Validation.Error
  alias Draught.Workspace.Path.Resolver

  @impl Draught.Tool.Executor
  def execute(%Call{arguments: %{"path" => relative}}, %Context{} = context, _configuration) do
    with {:ok, path} <- Resolver.resolve(context.workspace, relative, :read),
         {:ok, content} <- Reader.read(path, context.policy.max_output_bytes) do
      {:ok, content}
    else
      {:error, %Error{}} -> Failure.invalid_path()
      {:error, :too_large} -> Failure.file_too_large()
      {:error, :unreadable} -> Failure.read_failed()
    end
  end
end
