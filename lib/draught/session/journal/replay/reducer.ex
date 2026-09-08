defmodule Draught.Session.Journal.Replay.Reducer do
  @moduledoc """
  Applies ordered journal records to replay state while enforcing turn and iteration invariants.
  """

  alias Draught.Conversation
  alias Draught.Provider.Usage
  alias Draught.Session.Journal.Failure
  alias Draught.Session.Journal.Record
  alias Draught.Session.Journal.Replay

  @doc "Applies one validated journal record to replay state."
  @spec apply(Replay.t(), Record.t()) ::
          {:ok, Replay.t()} | {:error, Draught.Error.Normalized.t()}
  def apply(%Replay{} = replay, %Record{} = record) do
    with :ok <- sequence(replay, record),
         {:ok, transitioned} <- transition(replay, record.event) do
      {:ok, timestamps(transitioned, record)}
    end
  end

  @doc "Marks an unterminated final turn as interrupted after all records are applied."
  @spec finalize(Replay.t()) :: Replay.t()
  def finalize(%Replay{terminal: {:running, turn_id}} = replay) do
    messages = fallback_messages(replay.turn_base_messages, replay)

    %{
      replay
      | messages: Enum.reverse(messages),
        terminal: {:interrupted, turn_id},
        turn_base_messages: nil
    }
  end

  def finalize(%Replay{} = replay) do
    %{replay | messages: Enum.reverse(replay.messages), turn_base_messages: nil}
  end

  defp transition(replay, {:turn_started, turn_id, provider, request}) do
    expected_turn = replay.last_turn_id + 1

    replay
    |> valid_start?(turn_id, expected_turn)
    |> start_result(replay, request, turn_id, provider)
  end

  defp transition(replay, {:provider_result, turn_id, _iteration, {:ok, response}}) do
    with :ok <- active_turn(replay, turn_id) do
      {:ok,
       %{
         replay
         | messages: [response.message | replay.messages],
           usage: add_usage(replay.usage, response.usage)
       }}
    end
  end

  defp transition(replay, {:provider_result, turn_id, _iteration, {:error, _error}}) do
    with :ok <- active_turn(replay, turn_id) do
      {:ok, replay}
    end
  end

  defp transition(replay, {:tool_result, turn_id, _iteration, result}) do
    with :ok <- active_turn(replay, turn_id),
         {:ok, message} <- Conversation.tool(result) do
      {:ok, %{replay | messages: [message | replay.messages]}}
    else
      _result -> corrupt()
    end
  end

  defp transition(replay, {:turn_terminal, turn_id, {:ok, _response} = outcome}) do
    with :ok <- active_turn(replay, turn_id) do
      {:ok,
       %{
         replay
         | terminal: {:completed, turn_id, outcome},
           turn_base_messages: nil
       }}
    end
  end

  defp transition(replay, {:turn_terminal, turn_id, {:error, _error} = outcome}) do
    with :ok <- active_turn(replay, turn_id) do
      {:ok,
       %{
         replay
         | messages: fallback_messages(replay.turn_base_messages, replay),
           terminal: {:completed, turn_id, outcome},
           turn_base_messages: nil
       }}
    end
  end

  defp sequence(%Replay{next_sequence: expected}, %Record{sequence: expected}) do
    :ok
  end

  defp sequence(_replay, _record) do
    corrupt()
  end

  defp timestamps(replay, record) do
    created_at = replay.created_at || record.recorded_at

    %{
      replay
      | created_at: created_at,
        next_sequence: record.sequence + 1,
        updated_at: record.recorded_at
    }
  end

  defp active_turn(%Replay{terminal: {:running, turn_id}}, turn_id) do
    :ok
  end

  defp active_turn(_replay, _turn_id) do
    corrupt()
  end

  defp running?(%Replay{terminal: {:running, _turn_id}}) do
    true
  end

  defp running?(%Replay{}) do
    false
  end

  defp valid_start?(replay, turn_id, expected_turn) do
    turn_id == expected_turn and not running?(replay)
  end

  defp start_result(true, replay, request, turn_id, provider) do
    {:ok,
     %{
       replay
       | last_turn_id: turn_id,
         messages: Enum.reverse(request.messages),
         model: request.model,
         provider: provider,
         terminal: {:running, turn_id},
         turn_base_messages: replay.messages
     }}
  end

  defp start_result(false, _replay, _request, _turn_id, _provider) do
    corrupt()
  end

  defp add_usage(usage, nil) do
    usage
  end

  defp add_usage(nil, %Usage{} = usage) do
    usage
  end

  defp add_usage(%Usage{} = left, %Usage{} = right) do
    {:ok, usage} =
      Usage.new(
        input_tokens: left.input_tokens + right.input_tokens,
        output_tokens: left.output_tokens + right.output_tokens,
        cached_tokens: left.cached_tokens + right.cached_tokens,
        reasoning_tokens: left.reasoning_tokens + right.reasoning_tokens
      )

    usage
  end

  defp fallback_messages(nil, replay) do
    replay.messages
  end

  defp fallback_messages(messages, _replay) do
    messages
  end

  defp corrupt do
    {:error, Failure.corrupt()}
  end
end
