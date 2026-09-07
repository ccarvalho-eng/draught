defmodule Draught.Conversation.Document.Messages.Limits do
  @moduledoc false

  alias Draught.Validation.Error

  @maximum_message_bytes 4_194_304
  @maximum_total_bytes 16_777_216

  @doc "Returns the inclusive serialized-size limit for one message."
  @spec max_message_bytes() :: pos_integer()
  def max_message_bytes do
    @maximum_message_bytes
  end

  @doc "Returns the inclusive aggregate serialized-size limit for all messages."
  @spec max_total_bytes() :: pos_integer()
  def max_total_bytes do
    @maximum_total_bytes
  end

  @doc "Adds one canonical message to the aggregate serialized-size budget."
  @spec accumulate(term(), non_neg_integer(), non_neg_integer()) ::
          Error.result(non_neg_integer())
  def accumulate(message, index, total_bytes) do
    message_bytes = :erlang.external_size(message)
    next_total = total_bytes + message_bytes

    with :ok <- message_size_result(message_bytes, index),
         :ok <- total_size_result(next_total) do
      {:ok, next_total}
    end
  end

  defp message_size_result(message_bytes, _index)
       when message_bytes <= @maximum_message_bytes do
    :ok
  end

  defp message_size_result(_message_bytes, index) do
    Error.single(
      [:messages, index],
      :too_large,
      "serialized message must not exceed #{@maximum_message_bytes} bytes"
    )
  end

  defp total_size_result(total_bytes) when total_bytes <= @maximum_total_bytes do
    :ok
  end

  defp total_size_result(_total_bytes) do
    Error.single(
      [:messages],
      :too_large,
      "serialized messages must not exceed #{@maximum_total_bytes} bytes in total"
    )
  end
end
