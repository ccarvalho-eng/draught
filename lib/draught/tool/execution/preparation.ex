defmodule Draught.Tool.Execution.Preparation do
  @moduledoc false

  alias Draught.Tool.Call
  alias Draught.Tool.Definition
  alias Draught.Tool.Execution.Authorization
  alias Draught.Tool.Execution.Context
  alias Draught.Tool.Registry
  alias Draught.Tool.Schema.Arguments

  @type result ::
          {:ok, Definition.t()}
          | {:error, Draught.Error.Normalized.t()}
          | {:error, Draught.Validation.Error.t()}

  @doc "Resolves and authorizes a definition, then validates call arguments."
  @spec prepare(Registry.t(), Call.t(), Context.t()) :: result()
  def prepare(%Registry{} = registry, %Call{} = call, %Context{} = context) do
    with {:ok, definition} <- Registry.fetch(registry, call.name),
         :ok <- Authorization.check(definition.risk, context.policy),
         :ok <- Arguments.validate(call.arguments, definition.specification.input_schema) do
      {:ok, definition}
    end
  end
end
