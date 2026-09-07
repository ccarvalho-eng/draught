defmodule Draught.Execution.Runner.Configuration do
  @moduledoc """
  Injected provider, tools, policies, limits, and event sink for one agent run.
  """

  alias Draught.Execution.Runner.Configuration.Tools
  alias Draught.Execution.Runner.Event
  alias Draught.Execution.Runner.Limits
  alias Draught.Provider.Adapter
  alias Draught.Tool.Execution.Context
  alias Draught.Tool.Registry
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error

  @enforce_keys [:limits, :provider, :registry, :sink, :tool_context]
  defstruct [:limits, :provider, :registry, :sink, :tool_context]

  @type t :: %__MODULE__{
          limits: Limits.t(),
          provider: Draught.Provider.adapter(),
          registry: Registry.t(),
          sink: Event.sink(),
          tool_context: Context.t()
        }

  @doc "Builds a runner configuration and applies runner limits to tool execution."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes) do
    keys = [:limits, :provider, :registry, :sink, :tool_context]

    with {:ok, normalized} <- Attributes.normalize(attributes, keys) do
      build(normalized)
    end
  end

  defp build(attributes) do
    registry = Map.get(attributes, :registry)
    tool_context = Map.get(attributes, :tool_context)

    with {:ok, limits} <- limits(attributes),
         {:ok, provider} <- provider(attributes),
         {:ok, sink} <- sink(attributes),
         {:ok, {canonical_registry, canonical_context}} <-
           Tools.prepare(registry, tool_context, limits) do
      {:ok,
       %__MODULE__{
         limits: limits,
         provider: provider,
         registry: canonical_registry,
         sink: sink,
         tool_context: canonical_context
       }}
    end
  end

  defp limits(attributes) do
    case Map.get(attributes, :limits) do
      %Limits{} = limits -> rebuild_limits(limits)
      nil -> Limits.new()
      limits -> Limits.new(limits)
    end
  end

  defp rebuild_limits(limits) do
    attributes = Map.from_struct(limits)
    Limits.new(attributes)
  end

  defp provider(attributes) do
    provider = Map.get(attributes, :provider)

    case Adapter.validate(provider) do
      {:ok, _module, _configuration} -> {:ok, provider}
      {:error, _error} -> Error.single([:provider], :invalid_value, "must be a provider adapter")
    end
  end

  defp sink(%{sink: sink}) when is_function(sink, 1) do
    {:ok, sink}
  end

  defp sink(_attributes) do
    Error.single([:sink], :invalid_type, "must be a function with arity one")
  end
end
