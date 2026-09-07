defmodule Draught.Tool.Builtin.ListDirectory do
  @moduledoc """
  Defines the built-in confined directory-listing tool.
  """

  alias Draught.Tool.Builtin.ListDirectory.Executor
  alias Draught.Tool.Definition
  alias Draught.Validation.Error

  @doc "Builds the list-directory tool definition."
  @spec definition() :: Error.result(Definition.t())
  def definition do
    Definition.new(
      name: "list_directory",
      description: "List immediate entries in one workspace directory",
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
