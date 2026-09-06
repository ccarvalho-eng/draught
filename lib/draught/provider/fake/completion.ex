defmodule Draught.Provider.Fake.Completion do
  @moduledoc """
  An exact request-to-result route for the deterministic fake provider.
  """

  alias Draught.Error.Normalized
  alias Draught.Provider.Request
  alias Draught.Provider.Response
  alias Draught.Validation
  alias Draught.Validation.Attributes

  @enforce_keys [:request, :result]
  defstruct [:request, :result]

  @type result :: {:ok, Response.t()} | {:error, Normalized.t()}
  @type t :: %__MODULE__{request: Request.t(), result: result()}

  @doc "Builds a completion route with exactly one response or error."
  @spec new(map() | keyword()) :: Validation.result(t())
  def new(attributes) do
    with {:ok, normalized} <-
           Attributes.normalize(attributes, [:request, :response, :error, :result]),
         {:ok, request} <- request(normalized),
         {:ok, result} <- result(normalized) do
      {:ok, %__MODULE__{request: request, result: result}}
    end
  end

  defp request(attributes) do
    with {:ok, value} <- Attributes.fetch_required(attributes, :request) do
      case value do
        %Request{} = request ->
          request
          |> Map.from_struct()
          |> Request.new()

        external ->
          Request.new(external)
      end
    end
  end

  defp result(%{response: response} = attributes) when not is_map_key(attributes, :error) do
    case response do
      %Response{} = value -> normalize_response(value)
      external -> wrap_result(Response.new(external))
    end
  end

  defp result(%{error: error} = attributes) when not is_map_key(attributes, :response) do
    case error do
      %Normalized{} = value -> normalize_error(value)
      external -> wrap_error(Normalized.new(external))
    end
  end

  defp result(%{result: {:ok, response}} = attributes)
       when map_size(attributes) == 2 do
    normalize_response(response)
  end

  defp result(%{result: {:error, error}} = attributes)
       when map_size(attributes) == 2 do
    normalize_error(error)
  end

  defp result(_attributes) do
    Validation.error(
      [],
      :invalid_relationship,
      "must contain exactly one response or error"
    )
  end

  defp normalize_response(%Response{} = response) do
    response
    |> Map.from_struct()
    |> Response.new()
    |> wrap_result()
  end

  defp normalize_response(response) do
    response
    |> Response.new()
    |> wrap_result()
  end

  defp normalize_error(%Normalized{} = error) do
    error
    |> Map.from_struct()
    |> Normalized.new()
    |> wrap_error()
  end

  defp normalize_error(error) do
    error
    |> Normalized.new()
    |> wrap_error()
  end

  defp wrap_result({:ok, response}) do
    {:ok, {:ok, response}}
  end

  defp wrap_result({:error, _error} = result) do
    result
  end

  defp wrap_error({:ok, error}) do
    {:ok, {:error, error}}
  end

  defp wrap_error({:error, _error} = result) do
    result
  end
end
