defmodule Draught.Provider.OpenAI.Stream.ToolCalls.Configuration do
  @moduledoc false

  alias Draught.Provider.OpenAI.Protocol
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @default_max_calls 128
  @default_max_arguments_bytes 4_194_304
  @maximum_calls 1_024
  @maximum_arguments_bytes 8_388_608

  @enforce_keys [:max_calls, :max_arguments_bytes]
  defstruct [:max_calls, :max_arguments_bytes]

  @type t :: %__MODULE__{
          max_calls: pos_integer(),
          max_arguments_bytes: pos_integer()
        }

  @doc "Validates the retention limits used by streamed tool-call assembly."
  @spec new(map() | keyword()) :: {:ok, t()} | {:error, Draught.Error.Normalized.t()}
  def new(options) do
    with {:ok, attributes} <- normalize(options),
         {:ok, max_calls} <-
           bounded_option(attributes, :max_calls, @default_max_calls, @maximum_calls),
         {:ok, max_arguments_bytes} <-
           bounded_option(
             attributes,
             :max_arguments_bytes,
             @default_max_arguments_bytes,
             @maximum_arguments_bytes
           ) do
      {:ok,
       %__MODULE__{
         max_calls: max_calls,
         max_arguments_bytes: max_arguments_bytes
       }}
    end
  end

  defp normalize(options) do
    case Attributes.normalize(options, [:max_calls, :max_arguments_bytes]) do
      {:ok, attributes} ->
        {:ok, attributes}

      {:error, %Error{}} ->
        configuration_error("Stream configuration is invalid")
    end
  end

  defp bounded_option(attributes, key, default, maximum) do
    value = Map.get(attributes, key, default)
    result = Value.positive_integer(value, [key])
    bounded_option_result(result, maximum)
  end

  defp bounded_option_result({:ok, value}, maximum) when value <= maximum do
    {:ok, value}
  end

  defp bounded_option_result({:ok, _value}, _maximum) do
    configuration_error("Stream configuration exceeds the supported limit")
  end

  defp bounded_option_result({:error, %Error{}}, _maximum) do
    configuration_error("Stream configuration is invalid")
  end

  defp configuration_error(message) do
    Protocol.configuration("invalid_stream_configuration", message)
  end
end
