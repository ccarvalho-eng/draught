defmodule Draught.Tool.Builtin.RunCommand.Preparation do
  @moduledoc """
  Prepares an approved command for bounded subprocess execution.

  It validates structured input, obtains approval, resolves the workspace and
  executable, and supplies the controlled environment and execution limits.
  """

  alias Draught.Tool.Builtin.Approval
  alias Draught.Tool.Builtin.RunCommand.Environment
  alias Draught.Tool.Builtin.RunCommand.Executable
  alias Draught.Tool.Builtin.RunCommand.Execution
  alias Draught.Tool.Builtin.RunCommand.Input
  alias Draught.Tool.Call
  alias Draught.Tool.Execution.Context
  alias Draught.Workspace.Path.Resolver

  @doc "Prepares an approved process execution from a canonical tool call."
  @spec prepare(Call.t(), Context.t(), map()) :: {:ok, Execution.t()} | {:error, term()}
  def prepare(%Call{} = call, %Context{} = context, configuration) do
    with {:ok, input} <- Input.new(call.arguments),
         :ok <- authorize(call, context, input) do
      prepare_approved(input, context, configuration)
    end
  end

  defp prepare_approved(input, context, configuration) do
    with {:ok, workspace} <- Resolver.resolve(context.workspace, ".", :read),
         {:ok, environment, path} <- Environment.build(workspace, configuration),
         {:ok, executable} <- Executable.resolve(input.executable, workspace, path) do
      {:ok, execution(input, context, workspace, environment, executable)}
    end
  end

  defp authorize(call, context, input) do
    summary = "#{length(input.arguments)} arguments; isolated environment"
    Approval.authorize(call, context, :execute, input.executable, summary)
  end

  defp execution(input, context, workspace, environment, executable) do
    Execution.new(
      arguments: input.arguments,
      environment: environment,
      executable: executable,
      max_output_bytes: context.policy.max_output_bytes,
      timeout_ms: context.policy.timeout_ms,
      workspace: workspace
    )
  end
end
