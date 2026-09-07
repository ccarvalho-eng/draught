defmodule Draught.Tool.Builtin.WebFetch do
  @moduledoc """
  Defines the optional guarded page-fetch tool.
  """

  alias Draught.Tool.Builtin.WebFetch.Executor
  alias Draught.Tool.Definition
  alias Draught.Validation.Error

  @doc "Builds the guarded page-fetch tool definition."
  @spec definition() :: Error.result(Definition.t())
  def definition do
    Definition.new(
      name: "web_fetch",
      description: "Fetch one bounded HTTP(S) page as untrusted data with provenance",
      input_schema: %{
        "type" => "object",
        "additionalProperties" => false,
        "properties" => %{"url" => %{"type" => "string"}},
        "required" => ["url"]
      },
      risk: :network,
      executor: {Executor, nil}
    )
  end
end
