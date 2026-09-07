defmodule Draught.Provider.Ollama.Inventory do
  @moduledoc """
  Discovers installed Ollama models and classifies their required capabilities.

  Discovery is sequential and preserves the order returned by Ollama. A failed
  list or model-detail request returns its normalized discovery error rather
  than a partial inventory.
  """

  alias Draught.Provider.Ollama.Configuration
  alias Draught.Provider.Ollama.Discovery
  alias Draught.Provider.Ollama.Discovery.HTTP.Req
  alias Draught.Provider.Ollama.Inventory.Classifier
  alias Draught.Provider.Ollama.Inventory.Compatible
  alias Draught.Provider.Ollama.Inventory.Incompatible
  alias Draught.Provider.Ollama.Protocol

  @maximum_models 16

  @type entry :: Compatible.t() | Incompatible.t()
  @type result :: {:ok, [entry()]} | {:error, Draught.Error.Normalized.t()}

  @doc "Lists installed models through the production discovery client."
  @spec list(Configuration.t()) :: result()
  def list(%Configuration{} = configuration) do
    list(configuration, Req)
  end

  @doc "Lists installed models through an explicit discovery client."
  @spec list(Configuration.t(), module()) :: result()
  def list(%Configuration{} = configuration, http) do
    options = Map.from_struct(configuration.discovery)

    with {:ok, names} <- Discovery.list(options, http),
         :ok <- inventory_bound(names) do
      discover(names, configuration.required_capabilities, options, http)
    end
  end

  @doc "Filters compatible entries without changing inventory order."
  @spec compatible([entry()]) :: [Compatible.t()]
  def compatible(entries) when is_list(entries) do
    Enum.filter(entries, &match?(%Compatible{}, &1))
  end

  @doc "Filters incompatible entries without changing inventory order."
  @spec incompatible([entry()]) :: [Incompatible.t()]
  def incompatible(entries) when is_list(entries) do
    Enum.filter(entries, &match?(%Incompatible{}, &1))
  end

  defp discover(names, requirements, options, http) do
    names
    |> Enum.reduce_while({:ok, []}, fn name, {:ok, entries} ->
      case Discovery.fetch(name, options, http) do
        {:ok, model} -> {:cont, {:ok, [Classifier.classify(model, requirements) | entries]}}
        {:error, _error} = result -> {:halt, result}
      end
    end)
    |> reverse()
  end

  defp inventory_bound(names) do
    names
    |> Enum.count()
    |> inventory_bound_result()
  end

  defp inventory_bound_result(count) when count <= @maximum_models do
    :ok
  end

  defp inventory_bound_result(_count) do
    Protocol.inventory_too_large()
  end

  defp reverse({:ok, entries}) do
    {:ok, Enum.reverse(entries)}
  end

  defp reverse({:error, _error} = result) do
    result
  end
end
