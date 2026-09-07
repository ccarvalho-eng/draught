defmodule Draught.Tool.Builtin.ReplaceInFile do
  @moduledoc """
  Defines the built-in approved exact-replacement tool.
  """

  alias Draught.Tool.Builtin.ReplaceInFile.Executor
  alias Draught.Tool.Definition
  alias Draught.Validation.Error

  @doc "Builds the exact-replacement tool definition."
  @spec definition() :: Error.result(Definition.t())
  def definition do
    Definition.new(
      name: "replace_in_file",
      description: "Replace one exact text occurrence in a workspace file",
      input_schema: %{
        "type" => "object",
        "additionalProperties" => false,
        "properties" => %{
          "expected" => %{"type" => "string"},
          "path" => %{"type" => "string"},
          "replacement" => %{"type" => "string"}
        },
        "required" => ["path", "expected", "replacement"]
      },
      risk: :write,
      executor: {Executor, nil}
    )
  end
end
