defmodule Draught.Web.Search.Transport.Searxng.Decoder do
  @moduledoc """
  Decodes bounded SearXNG JSON results into canonical search-result fields.
  """

  alias Draught.Web.Search.Result.Item

  @doc "Decodes at most the effective result limit from a JSON response."
  @spec decode(binary(), pos_integer()) ::
          {:ok, [map()]} | {:error, :invalid_response}
  def decode(body, maximum) when is_binary(body) and is_integer(maximum) and maximum > 0 do
    case Jason.decode(body) do
      {:ok, %{"results" => results}} when is_list(results) -> decode_results(results, maximum)
      _result -> {:error, :invalid_response}
    end
  end

  def decode(_body, _maximum) do
    {:error, :invalid_response}
  end

  defp decode_results(results, maximum) do
    results
    |> Enum.take(maximum)
    |> Enum.reduce_while({:ok, []}, &item/2)
    |> reverse()
  end

  defp item(result, {:ok, items}) when is_map(result) do
    attributes = %{
      title: Map.get(result, "title"),
      url: Map.get(result, "url"),
      snippet: Map.get(result, "content", "") || ""
    }

    case Item.new(attributes) do
      {:ok, item} -> {:cont, {:ok, [project(item) | items]}}
      {:error, _error} -> {:halt, {:error, :invalid_response}}
    end
  end

  defp item(_result, {:ok, _items}) do
    {:halt, {:error, :invalid_response}}
  end

  defp project(%Item{} = item) do
    item
    |> Map.from_struct()
    |> Map.take([:snippet, :title, :url])
  end

  defp reverse({:ok, items}) do
    {:ok, Enum.reverse(items)}
  end

  defp reverse({:error, :invalid_response} = result) do
    result
  end
end
