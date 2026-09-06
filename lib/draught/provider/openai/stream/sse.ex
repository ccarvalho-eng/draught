defmodule Draught.Provider.OpenAI.Stream.SSE do
  @moduledoc """
  Incrementally parses bounded OpenAI-compatible server-sent events.
  """

  alias Draught.Error.Normalized
  alias Draught.Provider.OpenAI.Protocol
  alias Draught.Provider.OpenAI.Stream.SSE.Frame
  alias Draught.Validation.Attributes

  @default_maximum_bytes 1_048_576
  @maximum_configurable_bytes 8_388_608

  @enforce_keys [:buffer, :max_event_bytes, :status]
  defstruct [:buffer, :max_event_bytes, :status]

  @type status :: :open | :done
  @type t :: %__MODULE__{
          buffer: binary(),
          max_event_bytes: pos_integer(),
          status: status()
        }
  @type push_result ::
          {:ok, t(), [binary()]}
          | {:done, t(), [binary()]}
          | {:error, Normalized.t()}

  @doc "Builds a parser with a bounded maximum incomplete frame size."
  @spec new(map() | keyword()) :: {:ok, t()} | {:error, Normalized.t()}
  def new(options \\ []) do
    with {:ok, normalized} <- normalize_options(options),
         {:ok, maximum_bytes} <- maximum_bytes(normalized) do
      {:ok, %__MODULE__{buffer: "", max_event_bytes: maximum_bytes, status: :open}}
    end
  end

  @doc "Consumes one arbitrary binary chunk and returns ordered data values."
  @spec push(t(), term()) :: push_result()
  def push(%__MODULE__{status: :done}, _chunk) do
    data_after_done()
  end

  def push(%__MODULE__{} = parser, chunk) when is_binary(chunk) do
    normalized = normalize_newlines(parser.buffer <> chunk)
    {frames, buffer} = extract_frames(normalized, [])

    with :ok <- validate_buffer(buffer, parser.max_event_bytes),
         {:ok, status, data} <- consume_frames(frames, :open, [], parser.max_event_bytes),
         :ok <- validate_terminal_buffer(status, buffer) do
      next = %{parser | buffer: retained_buffer(status, buffer), status: status}
      push_result(status, next, data)
    end
  end

  def push(%__MODULE__{}, _chunk) do
    Protocol.error("invalid_stream_chunk", "provider stream chunk must be binary")
  end

  @doc "Verifies that transport closure follows the terminal SSE sentinel."
  @spec finish(t()) :: :ok | {:error, Normalized.t()}
  def finish(%__MODULE__{status: :done}) do
    :ok
  end

  def finish(%__MODULE__{status: :open}) do
    Protocol.error("incomplete_stream", "provider stream ended before its terminal sentinel")
  end

  defp normalize_options(options) do
    case Attributes.normalize(options, [:max_event_bytes]) do
      {:ok, normalized} -> {:ok, normalized}
      {:error, _error} -> invalid_configuration()
    end
  end

  defp maximum_bytes(options) do
    value = Map.get(options, :max_event_bytes, @default_maximum_bytes)
    maximum_bytes_result(value)
  end

  defp maximum_bytes_result(value)
       when is_integer(value) and value > 0 and value <= @maximum_configurable_bytes do
    {:ok, value}
  end

  defp maximum_bytes_result(_value) do
    invalid_configuration()
  end

  defp invalid_configuration do
    Protocol.configuration(
      "invalid_stream_configuration",
      "stream event byte limit is invalid"
    )
  end

  defp normalize_newlines(data) do
    String.replace(data, "\r\n", "\n")
  end

  defp extract_frames(data, frames) do
    case :binary.match(data, "\n\n") do
      {index, 2} -> extract_frame(data, frames, index)
      :nomatch -> {Enum.reverse(frames), data}
    end
  end

  defp extract_frame(data, frames, index) do
    <<frame::binary-size(^index), "\n\n", rest::binary>> = data
    extract_frames(rest, [frame | frames])
  end

  defp validate_buffer(buffer, maximum_bytes) when byte_size(buffer) <= maximum_bytes do
    :ok
  end

  defp validate_buffer(_buffer, _maximum_bytes) do
    Protocol.error("event_too_large", "provider stream event exceeds the byte limit")
  end

  defp consume_frames([], status, data, _maximum_bytes) do
    {:ok, status, Enum.reverse(data)}
  end

  defp consume_frames([frame | rest], status, data, maximum_bytes) do
    case Frame.decode(frame, maximum_bytes) do
      {:ok, :ignore} -> consume_frames(rest, status, data, maximum_bytes)
      {:ok, :done} -> consume_done(rest, status, data, maximum_bytes)
      {:ok, {:data, value}} -> consume_data(rest, status, data, maximum_bytes, value)
      {:error, %Normalized{}} = error -> error
    end
  end

  defp consume_done(rest, :open, data, maximum_bytes) do
    consume_frames(rest, :done, data, maximum_bytes)
  end

  defp consume_done(_rest, :done, _data, _maximum_bytes) do
    data_after_done()
  end

  defp consume_data(rest, :open, data, maximum_bytes, value) do
    consume_frames(rest, :open, [value | data], maximum_bytes)
  end

  defp consume_data(_rest, :done, _data, _maximum_bytes, _value) do
    data_after_done()
  end

  defp validate_terminal_buffer(:open, _buffer) do
    :ok
  end

  defp validate_terminal_buffer(:done, buffer) do
    buffer
    |> whitespace?()
    |> terminal_buffer_result()
  end

  defp whitespace?(<<>>) do
    true
  end

  defp whitespace?(<<byte, rest::binary>>) when byte in [9, 10, 13, 32] do
    whitespace?(rest)
  end

  defp whitespace?(_data) do
    false
  end

  defp terminal_buffer_result(true) do
    :ok
  end

  defp terminal_buffer_result(false) do
    data_after_done()
  end

  defp retained_buffer(:open, buffer) do
    buffer
  end

  defp retained_buffer(:done, _buffer) do
    ""
  end

  defp push_result(:open, parser, data) do
    {:ok, parser, data}
  end

  defp push_result(:done, parser, data) do
    {:done, parser, data}
  end

  defp data_after_done do
    Protocol.error(
      "data_after_done",
      "provider stream contained data after its terminal sentinel"
    )
  end
end
