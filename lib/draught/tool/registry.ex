defmodule Draught.Tool.Registry do
  @moduledoc """
  Immutable collection of executable tool definitions.
  """

  alias Draught.Error.Normalized
  alias Draught.Tool.Definition
  alias Draught.Validation.Error

  @enforce_keys [:definitions, :order]
  defstruct [:definitions, :order]

  @type t :: %__MODULE__{
          definitions: %{String.t() => Definition.t()},
          order: [String.t()]
        }

  @doc "Builds a registry and rejects invalid or duplicate definitions."
  @spec new([Definition.t()]) :: Error.result(t())
  def new(definitions) when is_list(definitions) do
    definitions
    |> Enum.reduce_while({:ok, %__MODULE__{definitions: %{}, order: []}}, &register/2)
    |> finalize()
  end

  def new(_definitions) do
    Error.single([], :invalid_type, "tool definitions must be a list")
  end

  @doc "Lists registered names in declaration order."
  @spec names(t()) :: [String.t()]
  def names(%__MODULE__{order: order}) do
    order
  end

  @doc "Lists portable specifications in declaration order."
  @spec specifications(t()) :: [Draught.Tool.Specification.t()]
  def specifications(%__MODULE__{} = registry) do
    Enum.map(registry.order, fn name -> registry.definitions[name].specification end)
  end

  @doc "Fetches a definition or returns a normalized unknown-tool error."
  @spec fetch(t(), term()) :: {:ok, Definition.t()} | {:error, Normalized.t()}
  def fetch(%__MODULE__{definitions: definitions}, name) do
    case Map.fetch(definitions, name) do
      {:ok, definition} -> {:ok, definition}
      :error -> unknown_tool()
    end
  end

  defp register(definition, {:ok, %__MODULE__{} = registry}) do
    with {:ok, canonical} <- canonical(definition),
         :ok <- unique(registry, canonical) do
      name = canonical.specification.name

      updated = %__MODULE__{
        registry
        | definitions: Map.put(registry.definitions, name, canonical),
          order: [name | registry.order]
      }

      {:cont, {:ok, updated}}
    else
      {:error, %Error{}} = result -> {:halt, result}
    end
  end

  defp canonical(%Definition{} = definition) do
    Definition.new(
      name: definition.specification.name,
      description: definition.specification.description,
      input_schema: definition.specification.input_schema,
      risk: definition.risk,
      executor: definition.executor
    )
  end

  defp canonical(_definition) do
    Error.single([], :invalid_type, "must contain tool definitions")
  end

  defp unique(registry, definition) do
    name = definition.specification.name
    unique_result(Map.has_key?(registry.definitions, name))
  end

  defp unique_result(false) do
    :ok
  end

  defp unique_result(true) do
    Error.single([:name], :duplicate_key, "tool names must be unique")
  end

  defp finalize({:ok, %__MODULE__{} = registry}) do
    {:ok, %__MODULE__{registry | order: Enum.reverse(registry.order)}}
  end

  defp finalize({:error, %Error{}} = result) do
    result
  end

  defp unknown_tool do
    {:ok, error} =
      Normalized.new(:tool, "unknown_tool", "Tool is not registered", retryable: false)

    {:error, error}
  end
end
