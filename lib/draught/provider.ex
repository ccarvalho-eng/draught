defmodule Draught.Provider do
  @moduledoc """
  Defines and enforces the provider adapter boundary.

  Adapters receive only canonical values. Draught validates every callback
  result before exposing it to callers.
  """

  alias Draught.Error.Normalized
  alias Draught.Event
  alias Draught.Provider.Adapter
  alias Draught.Provider.Capabilities
  alias Draught.Provider.Request
  alias Draught.Provider.Response
  alias Draught.Provider.Stream

  @type config :: term()
  @type adapter :: {module(), config()}
  @type adapter_sink :: (Event.nonterminal() -> :ok)
  @type consumer_sink :: (Event.t() -> :ok | :halt)
  @type provider_result(value) :: {:ok, value} | {:error, Normalized.t()}

  @doc "Returns the canonical capabilities advertised by an adapter."
  @callback capabilities(config()) :: provider_result(Capabilities.t())

  @doc "Completes one canonical request."
  @callback complete(Request.t(), config()) :: provider_result(Response.t())

  @doc """
  Emits nonterminal canonical events synchronously and returns the completed response.

  The adapter treats the sink as a synchronous control-flow boundary and must
  not catch or continue after the sink stops its callback. The facade owns
  cancellation and the single terminal event.
  """
  @callback stream(Request.t(), config(), adapter_sink()) :: provider_result(Response.t())

  @doc "Returns a provider's validated advertised capabilities."
  @spec capabilities(adapter()) :: provider_result(Capabilities.t())
  def capabilities(adapter) do
    with {:ok, module, config} <- Adapter.validate(adapter),
         result <- module.capabilities(config) do
      normalize_capabilities(result)
    end
  end

  @doc "Completes a request through an explicitly injected adapter."
  @spec complete(adapter(), Request.t() | map() | keyword()) :: provider_result(Response.t())
  def complete(adapter, request) do
    with {:ok, module, config} <- Adapter.validate(adapter),
         {:ok, canonical_request} <- normalize_request(request),
         result <- module.complete(canonical_request, config) do
      normalize_response(result)
    end
  end

  @doc "Streams validated events synchronously and returns the completed response."
  @spec stream(adapter(), Request.t() | map() | keyword(), consumer_sink()) ::
          provider_result(Response.t())
  def stream(adapter, request, sink) when is_function(sink, 1) do
    with {:ok, module, config} <- Adapter.validate(adapter),
         {:ok, canonical_request} <- normalize_request(request) do
      invoke_stream(module, config, canonical_request, sink)
    end
  end

  def stream(_adapter, _request, _sink) do
    configuration_error("stream sink must be a function with arity one")
  end

  defp normalize_request(%Request{} = request) do
    request
    |> Map.from_struct()
    |> Request.new()
    |> normalize_validation_result("request is invalid", :configuration)
  end

  defp normalize_request(request) do
    case Request.new(request) do
      {:ok, canonical_request} -> {:ok, canonical_request}
      {:error, _error} -> configuration_error("request is invalid")
    end
  end

  defp normalize_capabilities({:ok, %Capabilities{} = capabilities}) do
    capabilities
    |> Map.from_struct()
    |> Capabilities.new()
    |> normalize_validation_result("provider returned invalid capabilities")
  end

  defp normalize_capabilities({:error, error}) do
    normalize_provider_error(error)
  end

  defp normalize_capabilities(_result) do
    protocol_error("provider returned an invalid capabilities result")
  end

  defp normalize_response({:ok, %Response{} = response}) do
    response
    |> Map.from_struct()
    |> Response.new()
    |> normalize_validation_result("provider returned an invalid response")
  end

  defp normalize_response({:error, error}) do
    normalize_provider_error(error)
  end

  defp normalize_response(_result) do
    protocol_error("provider returned an invalid response result")
  end

  defp normalize_provider_error(%Normalized{} = error) do
    result =
      error
      |> Map.from_struct()
      |> Normalized.new()

    case result do
      {:ok, valid_error} -> {:error, valid_error}
      {:error, _error} -> protocol_error("provider returned an invalid error")
    end
  end

  defp normalize_provider_error(_error) do
    protocol_error("provider returned an invalid error")
  end

  defp normalize_validation_result({:ok, value}, _message) do
    {:ok, value}
  end

  defp normalize_validation_result({:error, _error}, message) do
    protocol_error(message)
  end

  defp normalize_validation_result({:ok, value}, _message, _kind) do
    {:ok, value}
  end

  defp normalize_validation_result({:error, _error}, message, :configuration) do
    configuration_error(message)
  end

  defp invoke_stream(module, config, request, sink) do
    Stream.invoke(module, config, request, sink, &normalize_response/1)
  end

  defp configuration_error(message) do
    {:error, configuration_error_value(message)}
  end

  defp configuration_error_value(message) do
    {:ok, error} =
      Normalized.new(:configuration, "invalid_configuration", message, retryable: false)

    error
  end

  defp protocol_error(message) do
    {:error, protocol_error_value(message)}
  end

  defp protocol_error_value(message) do
    {:ok, error} =
      Normalized.new(:protocol, "invalid_provider_result", message, retryable: false)

    error
  end
end
