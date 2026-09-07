defmodule Draught.Session.Failure do
  @moduledoc """
  Constructs bounded, user-safe failures for session lifecycle operations.
  """

  alias Draught.Error.Normalized

  @doc "Builds a missing-session failure."
  @spec not_found() :: Normalized.t()
  def not_found do
    error(:configuration, "session_not_found", "Session is not running")
  end

  @doc "Builds a duplicate-session failure."
  @spec already_started() :: Normalized.t()
  def already_started do
    error(:configuration, "session_already_started", "Session is already running")
  end

  @doc "Builds a session-start failure."
  @spec start_failed() :: Normalized.t()
  def start_failed do
    error(:protocol, "session_start_failed", "Session could not be started")
  end

  @doc "Builds a bounded failure when a live-session call cannot complete."
  @spec call_failed() :: Normalized.t()
  def call_failed do
    error(:protocol, "session_call_failed", "Session call could not be completed")
  end

  @doc "Builds an unknown-completion failure for a timed-out session call."
  @spec call_timeout() :: Normalized.t()
  def call_timeout do
    error(
      :timeout,
      "session_call_timeout",
      "Session call timed out; the requested operation may still complete"
    )
  end

  @doc "Builds a concurrent-turn rejection."
  @spec busy() :: Normalized.t()
  def busy do
    error(:policy, "session_busy", "Session already has an active turn")
  end

  @doc "Builds an inactive-session cancellation rejection."
  @spec no_active_turn() :: Normalized.t()
  def no_active_turn do
    error(:policy, "no_active_turn", "Session has no active turn")
  end

  @doc "Builds an invalid-subscriber failure."
  @spec invalid_subscriber() :: Normalized.t()
  def invalid_subscriber do
    error(:configuration, "invalid_subscriber", "Session subscriber must be a live process")
  end

  @doc "Builds an invalid runner-event acknowledgement failure."
  @spec invalid_acknowledgement() :: Normalized.t()
  def invalid_acknowledgement do
    error(
      :configuration,
      "invalid_session_acknowledgement",
      "Session acknowledgement must identify a live event and return :ok or :halt"
    )
  end

  @doc "Builds an explicit turn-cancellation outcome."
  @spec cancelled() :: Normalized.t()
  def cancelled do
    error(:cancellation, "session_cancelled", "Session turn was cancelled")
  end

  @doc "Builds a whole-turn timeout outcome."
  @spec timeout() :: Normalized.t()
  def timeout do
    error(:timeout, "session_timeout", "Session turn exceeded the configured timeout")
  end

  @doc "Builds an unexpected turn-task failure."
  @spec turn_failed() :: Normalized.t()
  def turn_failed do
    error(:protocol, "session_turn_failed", "Session turn task terminated unexpectedly")
  end

  @doc "Builds the recovery outcome for a turn interrupted by process termination."
  @spec interrupted() :: Normalized.t()
  def interrupted do
    error(:protocol, "session_interrupted", "Session turn was interrupted before completion")
  end

  defp error(kind, code, message) do
    {:ok, error} = Normalized.new(kind, code, message, retryable: false)
    error
  end
end
