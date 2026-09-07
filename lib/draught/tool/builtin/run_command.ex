defmodule Draught.Tool.Builtin.RunCommand do
  @moduledoc """
  Defines the built-in approved command-execution tool.
  """

  alias Draught.Tool.Builtin.RunCommand.Executor
  alias Draught.Tool.Definition
  alias Draught.Validation.Error

  @doc "Builds the command-execution tool definition."
  @spec definition() :: Error.result(Definition.t())
  def definition do
    Definition.new(
      name: "run_command",
      description: "Run an executable with an explicit argument list in the workspace",
      input_schema: %{
        "type" => "object",
        "additionalProperties" => false,
        "properties" => %{
          "arguments" => %{
            "type" => "array",
            "items" => %{"type" => "string"}
          },
          "executable" => %{"type" => "string"}
        },
        "required" => ["executable"]
      },
      risk: :execute,
      executor: {Executor, %{}}
    )
  end
end
