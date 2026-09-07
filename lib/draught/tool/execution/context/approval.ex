defmodule Draught.Tool.Execution.Context.Approval do
  @moduledoc """
  Normalizes approval policy configuration for a tool execution context.

  Missing configuration receives the default policy, while invalid adapters
  are converted to context validation errors.
  """

  alias Draught.Tool.Approval.Policy.Adapter
  alias Draught.Tool.Approval.Policy.Default
  alias Draught.Validation.Error

  @default {Default, nil}

  @doc "Reconstructs the injected approval policy or its safe default."
  @spec normalize(map()) :: Error.result(Draught.Tool.Approval.policy())
  def normalize(attributes) do
    approval = Map.get(attributes, :approval, @default)

    case Adapter.validate(approval) do
      {:ok, _module, _configuration} -> {:ok, approval}
      {:error, _error} -> Error.single([:approval], :invalid_value, "must be an approval policy")
    end
  end
end
