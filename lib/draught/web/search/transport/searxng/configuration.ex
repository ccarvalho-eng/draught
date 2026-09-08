defmodule Draught.Web.Search.Transport.Searxng.Configuration do
  @moduledoc """
  Validates a search endpoint and its guarded fetch adapter.

  Endpoints cannot contain query parameters because the request builder owns
  the complete query string for every search.
  """

  alias Draught.Validation.Attributes
  alias Draught.Web.Fetch.Transport.Mint
  alias Draught.Web.Target

  @enforce_keys [:endpoint, :fetch]
  defstruct [:endpoint, :fetch]

  @type adapter :: {module(), term()}
  @type t :: %__MODULE__{endpoint: String.t(), fetch: adapter()}
  @type error :: :invalid_configuration | :invalid_endpoint

  @doc "Builds a configuration with an explicit endpoint and guarded fetch adapter."
  @spec new(term()) :: {:ok, t()} | {:error, error()}
  def new(attributes) when is_list(attributes) or is_map(attributes) do
    case Attributes.normalize(attributes, [:endpoint, :fetch]) do
      {:ok, values} -> build(values)
      {:error, _error} -> {:error, :invalid_configuration}
    end
  end

  def new(_attributes) do
    {:error, :invalid_configuration}
  end

  defp build(values) do
    with {:ok, endpoint} <- endpoint(Map.get(values, :endpoint)),
         {:ok, fetch} <- fetch(Map.get(values, :fetch, {Mint, []})) do
      {:ok, %__MODULE__{endpoint: endpoint, fetch: fetch}}
    end
  end

  defp endpoint(value) when is_binary(value) do
    with {:ok, uri} <- URI.new(value),
         true <- is_nil(uri.query),
         {:ok, target} <- Target.new(value) do
      {:ok, target.logical_url}
    else
      _result -> {:error, :invalid_endpoint}
    end
  end

  defp endpoint(_value) do
    {:error, :invalid_endpoint}
  end

  defp fetch({module, _configuration} = adapter) when is_atom(module) do
    valid = Code.ensure_loaded?(module) and function_exported?(module, :fetch, 3)
    fetch_result(valid, adapter)
  end

  defp fetch(_adapter) do
    {:error, :invalid_configuration}
  end

  defp fetch_result(true, adapter) do
    {:ok, adapter}
  end

  defp fetch_result(false, _adapter) do
    {:error, :invalid_configuration}
  end
end
