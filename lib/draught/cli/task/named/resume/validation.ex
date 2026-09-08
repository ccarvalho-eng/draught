defmodule Draught.CLI.Task.Named.Resume.Validation do
  @moduledoc """
  Verifies that durable history and provider identity form a safe named-session continuation boundary.
  """

  alias Draught.CLI.Session.Binding
  alias Draught.CLI.Session.Failure
  alias Draught.CLI.Task.Preparation
  alias Draught.Conversation.Message.Assistant
  alias Draught.Session.Journal.Replay

  @doc "Checks that replay ended at a safe automatic continuation boundary."
  @spec resumable(Replay.t()) :: :ok | {:error, :session, Draught.CLI.Task.error()}
  def resumable(%Replay{terminal: :empty}) do
    {:error, :session, Failure.not_resumable()}
  end

  def resumable(%Replay{
        terminal: {:completed, _turn, {:ok, _response}},
        messages: messages
      }) do
    messages
    |> Enum.reverse()
    |> closed_history()
  end

  def resumable(%Replay{}) do
    {:error, :session, Failure.not_resumable()}
  end

  @doc "Verifies binding and replay identity against the prepared continuation."
  @spec verify(Binding.t(), Replay.t(), Preparation.t()) ::
          :ok | {:error, :session, Draught.CLI.Task.error()}
  def verify(binding, replay, preparation) do
    with :ok <- verify_binding(binding, preparation) do
      verify_replay(replay, preparation)
    end
  end

  defp closed_history([%Assistant{tool_calls: []} | _messages]) do
    :ok
  end

  defp closed_history(_messages) do
    {:error, :session, Failure.not_resumable()}
  end

  defp verify_replay(%Replay{} = replay, %Preparation{} = preparation) do
    current = {provider_name(preparation), preparation.request.model}
    recorded = {replay.provider, replay.model}

    replay_result(current == recorded)
  end

  defp replay_result(true) do
    :ok
  end

  defp replay_result(false) do
    {:error, :session, Failure.binding_mismatch()}
  end

  defp provider_name(%Preparation{runner: %{provider: {module, _configuration}}}) do
    Atom.to_string(module)
  end

  defp verify_binding(binding, preparation) do
    case Binding.verify(binding, preparation) do
      :ok -> :ok
      {:error, error} -> {:error, :session, error}
    end
  end
end
