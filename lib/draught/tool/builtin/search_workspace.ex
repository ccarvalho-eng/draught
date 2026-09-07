defmodule Draught.Tool.Builtin.SearchWorkspace do
  @moduledoc """
  Defines the built-in confined literal text-search tool.
  """

  alias Draught.Tool.Builtin.SearchWorkspace.Executor
  alias Draught.Tool.Definition
  alias Draught.Validation.Error

  @doc "Builds the workspace-search tool definition."
  @spec definition() :: Error.result(Definition.t())
  def definition do
    Definition.new(
      name: "search_workspace",
      description: "Search workspace UTF-8 files for literal text",
      input_schema: %{
        "type" => "object",
        "additionalProperties" => false,
        "properties" => %{
          "case_sensitive" => %{"type" => "boolean"},
          "path" => %{"type" => "string"},
          "query" => %{"type" => "string"}
        },
        "required" => ["query"]
      },
      risk: :read,
      executor: {Executor, nil}
    )
  end
end
