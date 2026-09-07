defmodule Draught.Web.Search.Result do
  @moduledoc """
  A bounded collection returned by an injected web-search adapter.
  """

  alias Draught.Validation.Error
  alias Draught.Web.Policy
  alias Draught.Web.Search.Result.Item

  @enforce_keys [:items]
  defstruct [:items]

  @type t :: %__MODULE__{items: [Item.t()]}

  @doc "Reconstructs and bounds search items under the effective policy."
  @spec new(term(), Policy.t()) :: Error.result(t())
  def new(items, %Policy{max_search_results: maximum}) when is_list(items) do
    items
    |> Enum.count_until(maximum + 1)
    |> bounded_items(items, maximum)
  end

  def new(_items, %Policy{}) do
    Error.single([:items], :invalid_value, "must be a bounded list of search results")
  end

  defp bounded_items(count, items, maximum) when count <= maximum do
    items
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, &item/2)
    |> result()
  end

  defp bounded_items(_count, _items, _maximum) do
    Error.single([:items], :invalid_value, "must be a bounded list of search results")
  end

  defp item({%Item{} = item, index}, {:ok, items}) do
    item
    |> Map.from_struct()
    |> Map.take([:title, :url, :snippet])
    |> Item.new()
    |> item_result(index, items)
  end

  defp item({attributes, index}, {:ok, items}) when is_map(attributes) or is_list(attributes) do
    attributes
    |> Item.new()
    |> item_result(index, items)
  end

  defp item({_attributes, index}, {:ok, _items}) do
    {:halt, Error.single([:items, index], :invalid_type, "must be a search result")}
  end

  defp item_result({:ok, item}, _index, items) do
    {:cont, {:ok, [item | items]}}
  end

  defp item_result({:error, %Error{} = error}, index, _items) do
    {:halt, {:error, prefix(error, index)}}
  end

  defp result({:ok, items}) do
    {:ok, %__MODULE__{items: Enum.reverse(items)}}
  end

  defp result({:error, %Error{}} = result) do
    result
  end

  defp prefix(error, index) do
    violations = Enum.map(error.violations, &%{&1 | path: [:items, index | &1.path]})
    Error.new(violations)
  end
end
