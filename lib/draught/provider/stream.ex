defmodule Draught.Provider.Stream do
  @moduledoc """
  Enforces the provider-neutral streaming boundary.

  It validates each nonterminal event, applies synchronous sink cancellation, and
  converts a provider's final result into a canonical terminal event.
  """

  alias Draught.Error.Normalized
  alias Draught.Event
  alias Draught.Event.Provider.Terminal

  @doc """
  Invokes a provider stream while enforcing event and sink contracts.

  The normalization function converts the provider's terminal return value into a
  canonical result. Invalid events, invalid sink returns, and sink cancellation
  stop the stream with a normalized error.
  """
  @spec invoke(
          module(),
          term(),
          Draught.Provider.Request.t(),
          Draught.Provider.consumer_sink(),
          function()
        ) ::
          Draught.Provider.provider_result(Draught.Provider.Response.t())
  def invoke(module, config, request, sink, normalize_result) do
    reference = make_ref()
    guarded_sink = guarded_sink(reference, sink)

    try do
      request
      |> module.stream(config, guarded_sink)
      |> normalize_result.()
      |> deliver_terminal(sink)
    catch
      {^reference, error} -> {:error, error}
    end
  end

  defp guarded_sink(reference, sink) do
    fn event ->
      case Event.validate(event) do
        {:ok, valid_event} -> validate_event(reference, sink, valid_event)
        {:error, _error} -> throw_error(reference, protocol_error())
      end
    end
  end

  defp validate_event(reference, sink, event) do
    case Event.type(event) do
      type when type in [:delta, :tool_call] -> validate_sink(reference, sink.(event))
      _type -> throw_error(reference, terminal_event_error())
    end
  end

  defp validate_sink(_reference, :ok) do
    :ok
  end

  defp validate_sink(reference, :halt) do
    throw_error(reference, cancellation_error())
  end

  defp validate_sink(reference, _result) do
    throw_error(reference, sink_error())
  end

  defp deliver_terminal(result, sink) do
    {:ok, event} = Terminal.new(result)
    terminal_sink_result(sink.(event), result)
  end

  defp terminal_sink_result(value, result) when value in [:ok, :halt] do
    result
  end

  defp terminal_sink_result(_value, _result) do
    {:error, sink_error()}
  end

  defp throw_error(reference, error) do
    throw({reference, error})
  end

  defp protocol_error do
    normalized_error(
      :protocol,
      "invalid_provider_result",
      "provider emitted an invalid event"
    )
  end

  defp terminal_event_error do
    normalized_error(
      :protocol,
      "invalid_provider_result",
      "provider emitted a terminal event"
    )
  end

  defp sink_error do
    normalized_error(
      :configuration,
      "invalid_configuration",
      "stream sink must return :ok or :halt"
    )
  end

  defp cancellation_error do
    normalized_error(
      :cancellation,
      "stream_cancelled",
      "stream sink requested cancellation"
    )
  end

  defp normalized_error(kind, code, message) do
    {:ok, error} = Normalized.new(kind, code, message, retryable: false)
    error
  end
end
