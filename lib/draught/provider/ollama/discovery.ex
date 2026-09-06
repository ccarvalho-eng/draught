defmodule Draught.Provider.Ollama.Discovery do
  @moduledoc """
  Reads installed models and their capabilities from Ollama's native API.
  """

  alias Draught.Provider.Ollama.Discovery.Configuration
  alias Draught.Provider.Ollama.Discovery.Decoder
  alias Draught.Provider.Ollama.Discovery.HTTP.Failure
  alias Draught.Provider.Ollama.Discovery.HTTP.Req
  alias Draught.Provider.Ollama.Discovery.HTTP.Response
  alias Draught.Provider.Ollama.Discovery.Model
  alias Draught.Provider.Ollama.Protocol

  @doc "Lists locally available Ollama model names."
  @spec list(map() | keyword()) :: {:ok, [String.t()]} | {:error, term()}
  def list(options \\ %{}) do
    list(options, Req)
  end

  @doc "Lists models through an explicit discovery HTTP implementation."
  @spec list(map() | keyword(), module()) :: {:ok, [String.t()]} | {:error, term()}
  def list(options, http) do
    with :ok <- validate_http(http),
         {:ok, configuration} <- Configuration.new(options),
         result <- http.request(:get, url(configuration, "/api/tags"), nil, configuration) do
      list_result(result)
    end
  end

  @doc "Fetches one installed Ollama model and its capabilities."
  @spec fetch(term(), map() | keyword()) :: {:ok, Model.t()} | {:error, term()}
  def fetch(model, options \\ %{}) do
    fetch(model, options, Req)
  end

  @doc "Fetches a model through an explicit discovery HTTP implementation."
  @spec fetch(term(), map() | keyword(), module()) :: {:ok, Model.t()} | {:error, term()}
  def fetch(model, options, http) do
    with :ok <- validate_http(http),
         {:ok, model_name} <- model_name(model),
         {:ok, configuration} <- Configuration.new(options),
         result <-
           http.request(
             :post,
             url(configuration, "/api/show"),
             %{"model" => model_name},
             configuration
           ) do
      model_result(result, model_name)
    end
  end

  defp list_result({:ok, %Response{status: 200, body: body}}) when is_binary(body) do
    Decoder.list(body)
  end

  defp list_result({:ok, %Response{status: status}}) do
    Protocol.http(status)
  end

  defp list_result({:error, %Failure{} = failure}) do
    Protocol.transport(failure)
  end

  defp model_result({:ok, %Response{status: 200, body: body}}, model) when is_binary(body) do
    Decoder.model(model, body)
  end

  defp model_result({:ok, %Response{status: 404}}, _model) do
    Protocol.model_not_found()
  end

  defp model_result({:ok, %Response{status: status}}, _model) do
    Protocol.http(status)
  end

  defp model_result({:error, %Failure{} = failure}, _model) do
    Protocol.transport(failure)
  end

  defp url(configuration, path) do
    configuration.base_url <> path
  end

  defp model_name(model) when is_binary(model) and byte_size(model) > 0 do
    model
    |> String.valid?()
    |> model_name_result(model)
  end

  defp model_name(_model) do
    Protocol.invalid_model()
  end

  defp model_name_result(true, model) do
    {:ok, model}
  end

  defp model_name_result(false, _model) do
    Protocol.invalid_model()
  end

  defp validate_http(http) when is_atom(http) do
    valid = Code.ensure_loaded?(http) and function_exported?(http, :request, 4)
    validate_http_result(valid)
  end

  defp validate_http(_http) do
    Protocol.invalid_http()
  end

  defp validate_http_result(true) do
    :ok
  end

  defp validate_http_result(false) do
    Protocol.invalid_http()
  end
end
