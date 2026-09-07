defmodule Draught.Tool.Builtin.ReadFile do
  @moduledoc """
  Defines the built-in confined file-reading tool.
  """

  alias Draught.Tool.Builtin.ReadFile.Executor
  alias Draught.Tool.Definition
  alias Draught.Validation.Error

  @doc "Builds the read-file tool definition."
  @spec definition() :: Error.result(Definition.t())
  def definition do
    Definition.new(
      name: "read_file",
      description: "Read one UTF-8 file from the workspace",
      input_schema: %{
        "type" => "object",
        "additionalProperties" => false,
        "properties" => %{"path" => %{"type" => "string"}},
        "required" => ["path"]
      },
      risk: :read,
      executor: {Executor, nil}
    )
  end
end
