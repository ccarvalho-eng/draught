defmodule Draught.Provider.OpenAI.Stream.Accumulator.Configuration do
  @moduledoc "Validates aggregate output and tool-call retention limits for one stream."

  alias Draught.Provider.OpenAI.Protocol
  alias Draught.Provider.OpenAI.Stream.ToolCalls
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @default_max_output_bytes 16_777_216
  @default_max_output_fragments 65_536
  @maximum_output_bytes 67_108_864
  @maximum_output_fragments 1_048_576

  @enforce_keys [:max_output_bytes, :max_output_fragments, :tool_calls]
  defstruct [:max_output_bytes, :max_output_fragments, :tool_calls]

  @type t :: %__MODULE__{
          max_output_bytes: pos_integer(),
          max_output_fragments: pos_integer(),
          tool_calls: ToolCalls.t()
        }

  @doc "Builds validated bounded accumulation configuration."
  @spec new(map() | keyword()) :: {:ok, t()} | {:error, Draught.Error.Normalized.t()}
  def new(options) do
    with {:ok, attributes} <- normalize(options),
         {:ok, max_output_bytes} <-
           bounded_option(
             attributes,
             :max_output_bytes,
             @default_max_output_bytes,
             @maximum_output_bytes
           ),
         {:ok, max_output_fragments} <-
           bounded_option(
             attributes,
             :max_output_fragments,
             @default_max_output_fragments,
             @maximum_output_fragments
           ),
         {:ok, tool_calls} <- tool_calls(attributes) do
      {:ok,
       %__MODULE__{
         max_output_bytes: max_output_bytes,
         max_output_fragments: max_output_fragments,
         tool_calls: tool_calls
       }}
    end
  end

  defp normalize(options) do
    allowed = [:max_output_bytes, :max_output_fragments | tool_option_keys()]

    case Attributes.normalize(options, allowed) do
      {:ok, attributes} ->
        {:ok, attributes}

      {:error, %Error{}} ->
        invalid_configuration("Stream configuration is invalid")
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
    invalid_configuration("Stream output limit exceeds the supported maximum")
  end

  defp bounded_option_result({:error, %Error{}}, _maximum) do
    invalid_configuration("Stream configuration is invalid")
  end

  defp tool_option_keys do
    [:max_calls, :max_arguments_bytes]
  end

  defp tool_calls(attributes) do
    options = Map.take(attributes, tool_option_keys())
    ToolCalls.new(options)
  end

  defp invalid_configuration(message) do
    Protocol.configuration("invalid_stream_configuration", message)
  end
end
