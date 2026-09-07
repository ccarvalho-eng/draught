defmodule Draught.CLI.Session.Failure do
  @moduledoc """
  Constructs stable failures for persistent-session storage, binding, and lifecycle operations.
  """

  alias Draught.Error.Normalized

  @doc "Builds a failure for a named session already owned by another process."
  @spec locked() :: Normalized.t()
  def locked do
    error(
      "session_locked",
      "The session is in use by another Draught process",
      "Wait for that process to finish, then try again"
    )
  end

  @doc "Builds a failure for a named session that already exists."
  @spec exists() :: Normalized.t()
  def exists do
    error(
      "session_already_exists",
      "The named session already exists",
      "Choose another name or resume the existing session"
    )
  end

  @doc "Builds a failure for a named session that does not exist."
  @spec missing() :: Normalized.t()
  def missing do
    error(
      "session_not_found",
      "The named session does not exist",
      "Create it with --session before attempting to resume it"
    )
  end

  @doc "Builds a failure for unavailable persistent session storage."
  @spec storage_unavailable() :: Normalized.t()
  def storage_unavailable do
    error(
      "session_storage_unavailable",
      "Persistent session storage is unavailable",
      "Check the user state directory and its permissions"
    )
  end

  @doc "Builds a failure for unsafe persistent session storage."
  @spec storage_unsafe() :: Normalized.t()
  def storage_unsafe do
    error(
      "session_storage_unsafe",
      "Persistent session storage contains an unsafe filesystem entry",
      "Inspect the Draught user state directory before continuing"
    )
  end

  @doc "Builds a failure when current provider selection differs from recorded session state."
  @spec binding_mismatch() :: Normalized.t()
  def binding_mismatch do
    error(
      "session_binding_mismatch",
      "The selected provider or model does not match the named session",
      "Resume with the provider and exact model recorded for this session"
    )
  end

  @doc "Builds a failure for missing, malformed, or unsafe session binding state."
  @spec invalid_binding() :: Normalized.t()
  def invalid_binding do
    error(
      "session_binding_invalid",
      "The named session binding is missing or invalid",
      "Inspect the session state before continuing"
    )
  end

  @doc "Builds a failure when the last durable turn is not safe to continue automatically."
  @spec not_resumable() :: Normalized.t()
  def not_resumable do
    error(
      "session_not_resumable",
      "The named session did not end at a successful conversation boundary",
      "Inspect the session history before starting recovery"
    )
  end

  defp error(code, message, hint) do
    {:ok, error} =
      Normalized.new(:configuration, code, message,
        hint: hint,
        retryable: false
      )

    error
  end
end
