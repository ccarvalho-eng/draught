defmodule Draught.Web.Search.Transport.Searxng do
  @moduledoc """
  Searches a configured SearXNG JSON endpoint through the guarded fetch boundary.

  The transport adds no network authority of its own. Endpoint resolution,
  address pinning, redirects, response limits, and deadlines remain governed by
  the injected fetch adapter and effective web policy.
  """

  @behaviour Draught.Web.Search.Adapter

  alias Draught.Error.Normalized
  alias Draught.Web.Failure
  alias Draught.Web.Fetch.Response
  alias Draught.Web.Policy
  alias Draught.Web.Search.Transport.Searxng.Configuration
  alias Draught.Web.Search.Transport.Searxng.Decoder
  alias Draught.Web.Search.Transport.Searxng.Request

  @impl Draught.Web.Search.Adapter
  def search(query, %Policy{} = policy, attributes) do
    attributes
    |> perform(query, policy)
    |> normalize()
  end

  defp perform(attributes, query, policy) do
    with {:ok, configuration} <- Configuration.new(attributes),
         {:ok, url} <- Request.build(configuration.endpoint, query) do
      retrieve(configuration.fetch, url, policy)
    end
  end

  defp retrieve(fetch_adapter, url, policy) do
    with {:ok, fetched} <- fetch(fetch_adapter, url, policy),
         {:ok, response} <- response(fetched, policy) do
      Decoder.decode(response.content, policy.max_search_results)
    end
  end

  defp normalize({:ok, items}) do
    {:ok, items}
  end

  defp normalize({:error, :invalid_endpoint}) do
    {:error, Failure.target_blocked()}
  end

  defp normalize({:error, reason})
       when reason in [:invalid_configuration, :invalid_response] do
    {:error, Failure.invalid_result()}
  end

  defp normalize({:error, %Normalized{}} = result) do
    result
  end

  defp normalize(_result) do
    {:error, Failure.invalid_result()}
  end

  defp fetch({module, configuration}, url, policy) do
    module.fetch(url, policy, configuration)
  end

  defp response(%Response{} = response, policy) do
    response
    |> Map.from_struct()
    |> response(policy)
  end

  defp response(attributes, policy) do
    case Response.new(attributes, policy) do
      {:ok, response} -> {:ok, response}
      {:error, _error} -> {:error, :invalid_response}
    end
  end
end
