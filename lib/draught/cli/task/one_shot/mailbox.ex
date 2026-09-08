defmodule Draught.CLI.Task.OneShot.Mailbox do
  @moduledoc """
  Selects only events belonging to the active session and terminal approval.

  Stale turn identifiers, input references, and approval scopes remain outside
  the active execution protocol and cannot advance its state.
  """

  alias Draught.CLI.Task.Approval.Prompt
  alias Draught.CLI.Task.Stream

  @type event ::
          {:terminal, term()}
          | :started
          | {:runner, term(), reference()}
          | :session_stopped
          | {:approval, {pid(), reference(), integer(), Draught.Tool.Approval.Request.t()}}
          | {:input, Draught.CLI.Interactive.Terminal.Adapter.input_result()}
          | :approval_stopped
          | :invalid_event
          | :elapsed

  @doc "Receives one correlated event without consuming unrelated caller messages."
  @spec next(String.t(), pos_integer(), Stream.t(), reference(), non_neg_integer()) :: event()
  def next(identifier, turn_id, stream, monitor, maximum) do
    timeout = Prompt.wait_timeout(stream.approval, maximum)
    references = Prompt.references(stream.approval)
    listen(identifier, turn_id, monitor, references, timeout)
  end

  defp listen(identifier, turn_id, monitor, {scope, input_reference, approval_monitor}, timeout) do
    receive do
      {:draught_session, ^identifier, event} when elem(event, 1) == turn_id ->
        session_event(event)

      {:DOWN, ^monitor, :process, _session, _reason} ->
        :session_stopped

      {:DOWN, ^approval_monitor, :process, _requester, _reason}
      when is_reference(approval_monitor) ->
        :approval_stopped

      {:draught_approval, ^scope, operation} when is_reference(scope) ->
        {:approval, operation}

      {:draught_terminal_input, ^input_reference, input} when is_reference(input_reference) ->
        {:input, input}
    after
      timeout -> :elapsed
    end
  end

  defp session_event({:turn_terminal, _turn_id, outcome}) do
    {:terminal, outcome}
  end

  defp session_event({:turn_started, _turn_id}) do
    :started
  end

  defp session_event({:runner, _turn_id, event, acknowledgement}) do
    {:runner, event, acknowledgement}
  end

  defp session_event(_event) do
    :invalid_event
  end
end
