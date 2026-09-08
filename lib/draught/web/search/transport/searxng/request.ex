defmodule Draught.Web.Search.Transport.Searxng.Request do
  @moduledoc """
  Builds one deterministic SearXNG JSON search URL.
  """

  @maximum_query_bytes 1_024

  @doc "Adds the bounded query and fixed JSON and safe-search parameters."
  @spec build(String.t(), term()) :: {:ok, String.t()} | {:error, :invalid_response}
  def build(endpoint, query)
      when is_binary(endpoint) and is_binary(query) and
             byte_size(query) in 1..@maximum_query_bytes do
    query
    |> String.valid?()
    |> build_valid(endpoint, query)
  end

  def build(_endpoint, _query) do
    {:error, :invalid_response}
  end

  defp build_valid(true, endpoint, query) do
    case URI.new(endpoint) do
      {:ok, uri} -> {:ok, encode(uri, query)}
      _result -> {:error, :invalid_response}
    end
  end

  defp build_valid(false, _endpoint, _query) do
    {:error, :invalid_response}
  end

  defp encode(uri, query) do
    parameters = [{"q", query}, {"format", "json"}, {"safesearch", "1"}]
    URI.to_string(%{uri | query: URI.encode_query(parameters)})
  end
end
