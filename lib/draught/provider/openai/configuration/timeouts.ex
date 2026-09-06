defmodule Draught.Provider.OpenAI.Configuration.Timeouts do
  @moduledoc """
  Bounded connection, receive, and overall request timeouts.
  """

  alias Draught.Validation.Attributes
  alias Draught.Validation.Error

  @maximum_ms 600_000

  defstruct connect_ms: 10_000, receive_ms: 60_000, request_ms: 120_000

  @type t :: %__MODULE__{
          connect_ms: pos_integer(),
          receive_ms: pos_integer(),
          request_ms: pos_integer()
        }

  @doc "Builds validated timeout settings capped at ten minutes."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes \\ %{}) do
    with {:ok, normalized} <-
           Attributes.normalize(attributes, [:connect_ms, :receive_ms, :request_ms]),
         {:ok, connect_ms} <- bounded(normalized, :connect_ms, 10_000),
         {:ok, receive_ms} <- bounded(normalized, :receive_ms, 60_000),
         {:ok, request_ms} <- bounded(normalized, :request_ms, 120_000) do
      {:ok,
       %__MODULE__{
         connect_ms: connect_ms,
         receive_ms: receive_ms,
         request_ms: request_ms
       }}
    end
  end

  defp bounded(attributes, key, default) do
    value = Map.get(attributes, key, default)
    bounded_result(value, key)
  end

  defp bounded_result(value, _key)
       when is_integer(value) and value > 0 and value <= @maximum_ms do
    {:ok, value}
  end

  defp bounded_result(_value, key) do
    Error.single([key], :invalid_value, "must be an integer from 1 to #{@maximum_ms}")
  end
end
