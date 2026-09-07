defmodule Draught.CLI.Task.Preparation.Tools do
  @moduledoc """
  Builds the standard workspace tool registry and applies CLI web-capability policy.
  """

  alias Draught.CLI.Task.Risk
  alias Draught.Tool.Builtin
  alias Draught.Tool.Execution.Context
  alias Draught.Tool.Execution.Policy
  alias Draught.Tool.Registry
  alias Draught.Validation.Error
  alias Draught.Web.Capability

  @type prepared :: {Registry.t(), Context.t()}

  @doc "Builds the bounded registry, execution context, and runner limits."
  @spec prepare(map(), String.t()) :: Error.result(prepared())
  def prepare(attributes, workspace) do
    with {:ok, capability} <- Capability.new(),
         {:ok, registry} <- registry(attributes, capability),
         {:ok, context} <- context(attributes, workspace, capability) do
      {:ok, {registry, context}}
    end
  end

  defp registry(%{registry: %Registry{} = registry}, _capability) do
    definitions = Enum.map(registry.order, &Map.fetch!(registry.definitions, &1))
    Registry.new(definitions)
  end

  defp registry(%{registry: _registry}, _capability) do
    Error.single([:registry], :invalid_type, "must be a tool registry")
  end

  defp registry(_attributes, capability) do
    Builtin.registry(web: capability)
  end

  defp context(attributes, workspace, capability) do
    risk = Map.get(attributes, :risk, :ask)

    with {:ok, {allowed_risks, default_approval}} <- Risk.resolve(risk),
         {:ok, policy} <- Policy.new(allowed_risks: allowed_risks) do
      Context.new(
        workspace: workspace,
        policy: policy,
        approval: Map.get(attributes, :approval, default_approval),
        web: capability
      )
    end
  end
end
