defmodule Draught.Session do
  @moduledoc """
  Starts and controls supervised Draught agent sessions by portable identifier.

  Cancellation discards the active runner result and emits a terminal cancellation
  event. Effects completed before cancellation are not rolled back.
  """

  alias Draught.Error.Normalized
  alias Draught.Session.Identifier
  alias Draught.Session.Journal.Replay
  alias Draught.Session.LocalJournal
  alias Draught.Session.Runtime.Client
  alias Draught.Session.Settings
  alias Draught.Session.Status
  alias Draught.Validation.Error

  @type lookup_result :: {:ok, pid()} | {:error, Normalized.t() | Error.t()}
  @type operation_result(value) :: {:ok, value} | {:error, Normalized.t() | Error.t()}

  @doc "Starts one dynamically supervised session with an explicit runner configuration."
  @spec start(term(), term(), keyword() | map()) :: operation_result(pid())
  def start(identifier, runner_configuration, options \\ []) do
    with {:ok, settings} <- Settings.new(identifier, runner_configuration, options) do
      Client.start(settings)
    end
  end

  @doc "Starts one asynchronous turn and returns its monotonic session-local identifier."
  @spec run(term(), term(), pid()) :: operation_result(pos_integer())
  def run(identifier, request, subscriber \\ self()) do
    with {:ok, canonical} <- Identifier.new(identifier) do
      Client.call(canonical, {:run, request, subscriber})
    end
  end

  @doc "Returns a responsive snapshot of the session lifecycle state."
  @spec status(term()) :: operation_result(Status.t())
  def status(identifier) do
    with {:ok, canonical} <- Identifier.new(identifier) do
      Client.call(canonical, :status)
    end
  end

  @doc "Cancels the active turn and records an explicit cancellation outcome."
  @spec cancel(term()) :: :ok | {:error, Normalized.t() | Error.t()}
  def cancel(identifier) do
    with {:ok, canonical} <- Identifier.new(identifier) do
      Client.call(canonical, :cancel)
    end
  end

  @doc "Stops a session after terminating any active turn."
  @spec stop(term()) :: :ok | {:error, Normalized.t() | Error.t()}
  def stop(identifier) do
    with {:ok, canonical} <- Identifier.new(identifier) do
      Client.call(canonical, :stop)
    end
  end

  @doc "Writes a disposable atomic checkpoint for a running session."
  @spec checkpoint(term()) :: :ok | {:error, Normalized.t() | Error.t()}
  def checkpoint(identifier) do
    with {:ok, canonical} <- Identifier.new(identifier) do
      Client.call(canonical, :checkpoint)
    end
  end

  @doc "Replays a workspace-local session journal without starting a session."
  @spec replay(term(), term(), map() | keyword()) :: operation_result(Replay.t())
  def replay(workspace, identifier, options \\ []) do
    LocalJournal.replay(workspace, identifier, options)
  end

  @doc "Looks up a live session through the session registry."
  @spec whereis(term()) :: lookup_result()
  def whereis(identifier) do
    with {:ok, canonical} <- Identifier.new(identifier) do
      Client.whereis(canonical)
    end
  end
end
