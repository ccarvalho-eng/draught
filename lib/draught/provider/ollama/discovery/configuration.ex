defmodule Draught.Provider.Ollama.Discovery.Configuration do
  @moduledoc """
  Bounded connection settings for Ollama's native discovery API.
  """

  alias Draught.Provider.OpenAI.Configuration.Endpoint
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @keys [
    :base_url,
    :connect_timeout_ms,
    :receive_timeout_ms,
    :request_timeout_ms,
    :max_response_bytes
  ]
  @default_base_url "http://localhost:11434"
  @maximum_timeout_ms 600_000
  @maximum_response_bytes 8 * 1024 * 1024

  defstruct base_url: @default_base_url,
            connect_timeout_ms: 2_000,
            receive_timeout_ms: 5_000,
            request_timeout_ms: 10_000,
            max_response_bytes: 1024 * 1024

  @type t :: %__MODULE__{
          base_url: String.t(),
          connect_timeout_ms: pos_integer(),
          receive_timeout_ms: pos_integer(),
          request_timeout_ms: pos_integer(),
          max_response_bytes: pos_integer()
        }

  @doc "Builds validated discovery connection settings."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes \\ %{}) do
    with {:ok, normalized} <- Attributes.normalize(attributes, @keys) do
      build(normalized)
    end
  end

  defp build(attributes) do
    with {:ok, base_url} <- base_url(attributes),
         {:ok, timeouts} <- timeouts(attributes),
         {:ok, max_response_bytes} <- response_limit(attributes) do
      {connect_timeout_ms, receive_timeout_ms, request_timeout_ms} = timeouts

      {:ok,
       %__MODULE__{
         base_url: base_url,
         connect_timeout_ms: connect_timeout_ms,
         receive_timeout_ms: receive_timeout_ms,
         request_timeout_ms: request_timeout_ms,
         max_response_bytes: max_response_bytes
       }}
    end
  end

  defp timeouts(attributes) do
    with {:ok, connect_timeout_ms} <- timeout(attributes, :connect_timeout_ms, 2_000),
         {:ok, receive_timeout_ms} <- timeout(attributes, :receive_timeout_ms, 5_000),
         {:ok, request_timeout_ms} <- timeout(attributes, :request_timeout_ms, 10_000) do
      {:ok, {connect_timeout_ms, receive_timeout_ms, request_timeout_ms}}
    end
  end

  defp base_url(attributes) do
    attributes
    |> Map.get(:base_url, @default_base_url)
    |> Endpoint.new()
  end

  defp timeout(attributes, key, default) do
    value = Map.get(attributes, key, default)

    with {:ok, timeout} <- Value.positive_integer(value, [key]),
         true <- timeout <= @maximum_timeout_ms do
      {:ok, timeout}
    else
      false -> Error.single([key], :invalid_value, "must not exceed #{@maximum_timeout_ms}")
      {:error, %Error{}} = result -> result
    end
  end

  defp response_limit(attributes) do
    value = Map.get(attributes, :max_response_bytes, 1024 * 1024)

    with {:ok, limit} <- Value.positive_integer(value, [:max_response_bytes]),
         true <- limit <= @maximum_response_bytes do
      {:ok, limit}
    else
      false ->
        Error.single(
          [:max_response_bytes],
          :invalid_value,
          "must not exceed #{@maximum_response_bytes}"
        )

      {:error, %Error{}} = result ->
        result
    end
  end
end
