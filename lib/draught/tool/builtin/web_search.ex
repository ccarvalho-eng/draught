defmodule Draught.Tool.Builtin.WebSearch do
  @moduledoc """
  Defines the optional provider-neutral web-search tool.
  """

  alias Draught.Tool.Builtin.WebSearch.Executor
  alias Draught.Tool.Definition
  alias Draught.Validation.Error

  @doc "Builds the web-search tool definition."
  @spec definition() :: Error.result(Definition.t())
  def definition do
    Definition.new(
      name: "web_search",
      description: "Search the web and return bounded untrusted results with provenance",
      input_schema: %{
        "type" => "object",
        "additionalProperties" => false,
        "properties" => %{"query" => %{"type" => "string"}},
        "required" => ["query"]
      },
      risk: :network,
      executor: {Executor, nil}
    )
  end
end
