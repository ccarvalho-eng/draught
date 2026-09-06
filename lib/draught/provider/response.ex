defmodule Draught.Provider.Response do
  @moduledoc """
  A completed provider response with canonical assistant output and usage.
  """

  alias Draught.Conversation.Message.Assistant
  alias Draught.Provider.Usage
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @finish_reasons [:content_filter, :length, :other, :stop, :tool_calls]

  @enforce_keys [:message, :finish_reason]
  defstruct [:message, :finish_reason, :usage]

  @type finish_reason :: :content_filter | :length | :other | :stop | :tool_calls
  @type t :: %__MODULE__{
          message: Assistant.t(),
          finish_reason: finish_reason(),
          usage: Usage.t() | nil
        }

  @doc "Builds a validated canonical provider response."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes) do
    with {:ok, normalized} <-
           Attributes.normalize(attributes, [:message, :finish_reason, :usage]),
         {:ok, finish_reason} <- finish_reason(normalized),
         {:ok, message} <- message(normalized, finish_reason),
         {:ok, usage} <- usage(normalized),
         :ok <- validate_finish_reason(message, finish_reason) do
      {:ok, %__MODULE__{message: message, finish_reason: finish_reason, usage: usage}}
    end
  end

  defp message(attributes, finish_reason) do
    with {:ok, value} <- Attributes.fetch_required(attributes, :message) do
      normalize_message(value, finish_reason)
    end
  end

  defp normalize_message(%Assistant{content: [], tool_calls: []}, :content_filter) do
    {:ok, Assistant.filtered()}
  end

  defp normalize_message(%Assistant{} = message, _finish_reason) do
    message
    |> Map.from_struct()
    |> Assistant.new()
  end

  defp normalize_message(message, _finish_reason) when is_map(message) or is_list(message) do
    Assistant.new(message)
  end

  defp normalize_message(_message, _finish_reason) do
    Error.single([:message], :invalid_type, "must be an assistant message")
  end

  defp finish_reason(attributes) do
    with {:ok, value} <- Attributes.fetch_required(attributes, :finish_reason) do
      Value.enum(value, @finish_reasons, [:finish_reason])
    end
  end

  defp usage(attributes) do
    case Map.get(attributes, :usage) do
      nil ->
        {:ok, nil}

      %Usage{} = usage ->
        usage
        |> Map.from_struct()
        |> Usage.new()

      usage ->
        Usage.new(usage)
    end
  end

  defp validate_finish_reason(%Assistant{tool_calls: [_call | _rest]}, :tool_calls) do
    :ok
  end

  defp validate_finish_reason(%Assistant{content: [], tool_calls: []}, :content_filter) do
    :ok
  end

  defp validate_finish_reason(%Assistant{tool_calls: []}, reason) when reason != :tool_calls do
    :ok
  end

  defp validate_finish_reason(_message, _reason) do
    Error.single(
      [:finish_reason],
      :invalid_relationship,
      "must be tool_calls exactly when the message contains tool calls"
    )
  end
end
