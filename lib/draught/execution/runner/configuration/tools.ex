defmodule Draught.Execution.Runner.Configuration.Tools do
  @moduledoc false

  alias Draught.Execution.Runner.Limits
  alias Draught.Tool.Execution.Context
  alias Draught.Tool.Execution.Policy
  alias Draught.Tool.Registry
  alias Draught.Validation.Error

  @doc "Reconstructs the registry and applies runner limits to the tool context."
  @spec prepare(term(), term(), Limits.t()) :: Error.result({Registry.t(), Context.t()})
  def prepare(%Registry{} = registry, %Context{} = context, %Limits{} = limits) do
    with {:ok, canonical_registry} <- registry(registry),
         {:ok, canonical_context} <- context(context, limits) do
      {:ok, {canonical_registry, canonical_context}}
    end
  end

  def prepare(_registry, _context, %Limits{}) do
    Error.single([:tools], :invalid_type, "must contain a registry and execution context")
  end

  defp registry(%Registry{definitions: definitions, order: order})
       when is_map(definitions) and is_list(order) do
    order
    |> Enum.reduce_while({:ok, []}, fn name, {:ok, canonical} ->
      registry_definition(Map.fetch(definitions, name), canonical)
    end)
    |> rebuild_registry()
  end

  defp registry(%Registry{}) do
    Error.single([:registry], :invalid_value, "must be a canonical tool registry")
  end

  defp context(context, limits) do
    canonical_result =
      context
      |> Map.from_struct()
      |> Context.new()

    with {:ok, canonical} <- canonical_result,
         {:ok, policy} <- policy(canonical, limits) do
      Context.new(
        workspace: canonical.workspace,
        policy: policy,
        approval: canonical.approval,
        web: canonical.web
      )
    end
  end

  defp registry_definition({:ok, definition}, canonical) do
    {:cont, {:ok, [definition | canonical]}}
  end

  defp registry_definition(:error, _canonical) do
    {:halt, Error.single([:registry], :invalid_value, "must be a canonical tool registry")}
  end

  defp rebuild_registry({:ok, definitions}) do
    definitions
    |> Enum.reverse()
    |> Registry.new()
  end

  defp rebuild_registry({:error, %Error{}} = result) do
    result
  end

  defp policy(context, limits) do
    Policy.new(
      allowed_risks: context.policy.allowed_risks,
      max_output_bytes: limits.max_output_bytes,
      timeout_ms: limits.tool_timeout_ms
    )
  end
end
