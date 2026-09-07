defmodule Draught.Conversation.Document.Messages do
  @moduledoc false

  alias Draught.Conversation.Document.Collection
  alias Draught.Conversation.Document.Messages.FilteredAssistant
  alias Draught.Conversation.Document.Messages.Limits
  alias Draught.Conversation.Message
  alias Draught.Conversation.Message.Assistant
  alias Draught.Validation.Error

  @maximum_messages 1_000

  @doc "Normalizes and validates a non-empty bounded message collection."
  @spec normalize(term()) :: Error.result([Message.t()])
  def normalize(messages) when is_list(messages) and messages != [] do
    with :ok <- validate_count(messages) do
      messages
      |> Enum.with_index()
      |> Enum.reduce_while({:ok, [], 0}, &normalize_message/2)
      |> Collection.finish()
    end
  end

  def normalize([]) do
    Error.single([:messages], :required, "must contain at least one message")
  end

  def normalize(_messages) do
    Error.single([:messages], :invalid_type, "must be a list")
  end

  defp validate_count(messages) do
    messages
    |> length()
    |> count_result()
  end

  defp count_result(count) when count <= @maximum_messages do
    :ok
  end

  defp count_result(_count) do
    Error.single(
      [:messages],
      :too_large,
      "must not contain more than #{@maximum_messages} messages"
    )
  end

  defp normalize_message({message, index}, {:ok, normalized, total_bytes}) do
    case canonical_message(message) do
      {:ok, canonical} ->
        accumulate(canonical, index, normalized, total_bytes)

      {:error, %Error{} = error} ->
        {:halt, {:error, Collection.prefix_error(error, [:messages, index])}}
    end
  end

  defp accumulate(message, index, normalized, total_bytes) do
    case Limits.accumulate(message, index, total_bytes) do
      {:ok, next_total} -> {:cont, {:ok, [message | normalized], next_total}}
      {:error, %Error{}} = result -> {:halt, result}
    end
  end

  defp canonical_message(%Assistant{content: [], tool_calls: []} = message) do
    {:ok, message}
  end

  defp canonical_message(message) when is_struct(message) do
    Message.validate(message)
  end

  defp canonical_message(message) when is_map(message) or is_list(message) do
    case FilteredAssistant.normalize(message) do
      {:ok, %Assistant{}} = result -> result
      :not_filtered -> Message.new(message)
    end
  end

  defp canonical_message(_message) do
    Error.single([], :invalid_type, "must be a canonical message or message attributes")
  end
end
