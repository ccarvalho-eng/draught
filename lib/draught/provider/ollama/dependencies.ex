defmodule Draught.Provider.Ollama.Dependencies do
  @moduledoc """
  Explicit effect dependencies used by the Ollama adapter.
  """

  alias Draught.Provider.Ollama.Discovery.HTTP
  alias Draught.Provider.OpenAI.Transport
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error

  @enforce_keys [:discovery_http, :provider_transport]
  defstruct [:discovery_http, :provider_transport]

  @type t :: %__MODULE__{
          discovery_http: module(),
          provider_transport: {module(), term()}
        }

  @doc "Builds explicit discovery and provider transport dependencies."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes \\ %{}) do
    with {:ok, normalized} <-
           Attributes.normalize(attributes, [:discovery_http, :provider_transport]),
         {:ok, discovery_http} <- discovery_http(normalized),
         {:ok, provider_transport} <- provider_transport(normalized) do
      {:ok,
       %__MODULE__{
         discovery_http: discovery_http,
         provider_transport: provider_transport
       }}
    end
  end

  defp discovery_http(attributes) do
    module = Map.get(attributes, :discovery_http, HTTP.Req)

    valid =
      is_atom(module) and Code.ensure_loaded?(module) and function_exported?(module, :request, 4)

    dependency_result(valid, module, :discovery_http)
  end

  defp provider_transport(attributes) do
    transport = Map.get(attributes, :provider_transport, {Transport.Req, nil})

    case transport do
      {module, _configuration} when is_atom(module) ->
        valid = Code.ensure_loaded?(module) and provider_callbacks?(module)
        dependency_result(valid, transport, :provider_transport)

      _transport ->
        dependency_result(false, transport, :provider_transport)
    end
  end

  defp provider_callbacks?(module) do
    function_exported?(module, :complete, 2) and function_exported?(module, :stream, 4)
  end

  defp dependency_result(true, value, _key) do
    {:ok, value}
  end

  defp dependency_result(false, _value, key) do
    Error.single([key], :invalid_value, "must implement the required transport contract")
  end
end
