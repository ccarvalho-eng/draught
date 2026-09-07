defmodule Draught.Tool.Builtin.RunCommand.Executor do
  @moduledoc """
  Executes the built-in command tool through its preparation and process boundaries.

  Preparation handles validation, approval, confinement, and executable
  resolution before the subprocess is started and awaited.
  """

  @behaviour Draught.Tool.Executor

  alias Draught.Tool.Builtin.RunCommand.Failure
  alias Draught.Tool.Builtin.RunCommand.Preparation
  alias Draught.Tool.Builtin.RunCommand.Subprocess
  alias Draught.Tool.Call
  alias Draught.Tool.Execution.Context

  @impl Draught.Tool.Executor
  def execute(%Call{} = call, %Context{} = context, configuration) do
    with {:ok, execution} <- Preparation.prepare(call, context, configuration),
         {:ok, handle} <- Subprocess.start(execution) do
      Subprocess.await(handle)
    else
      {:error, _reason} = result -> Failure.normalize(result)
    end
  end
end
