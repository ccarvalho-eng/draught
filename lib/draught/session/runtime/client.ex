defmodule Draught.Session.Runtime.Client do
  @moduledoc """
  Provides bounded calls into a live session process and normalizes process-exit failures.
  """

  alias Draught.Session.Failure
  alias Draught.Session.Runtime.Server
  alias Draught.Session.Settings

  @doc "Starts one session under the dynamic session supervisor."
  @spec start(Settings.t()) :: {:ok, pid()} | {:error, Draught.Error.Normalized.t()}
  def start(%Settings{} = settings) do
    child_spec = Server.child_spec(settings)

    Draught.Session.DynamicSupervisor
    |> DynamicSupervisor.start_child(child_spec)
    |> start_result()
  end

  @doc "Calls a running session by canonical identifier."
  @spec call(String.t(), term()) :: term()
  def call(identifier, message) do
    call(identifier, message, 5_000)
  end

  @doc false
  @spec call(String.t(), term(), timeout()) :: term()
  def call(identifier, message, timeout) do
    with {:ok, session} <- whereis(identifier) do
      safe_call(session, message, timeout)
    end
  end

  @doc "Looks up a running session by canonical identifier."
  @spec whereis(String.t()) :: {:ok, pid()} | {:error, Draught.Error.Normalized.t()}
  def whereis(identifier) do
    case Registry.lookup(Draught.Session.Registry, identifier) do
      [{session, _value}] -> alive_result(:erlang.is_process_alive(session), session)
      [] -> {:error, Failure.not_found()}
    end
  end

  defp alive_result(true, session) do
    {:ok, session}
  end

  defp alive_result(false, _session) do
    {:error, Failure.not_found()}
  end

  defp safe_call(session, message, timeout) do
    GenServer.call(session, message, timeout)
  catch
    :exit, {:timeout, {GenServer, :call, _details}} -> {:error, Failure.call_timeout()}
    :exit, _reason -> {:error, Failure.call_failed()}
  end

  defp start_result({:ok, session}) do
    {:ok, session}
  end

  defp start_result({:error, {:already_started, _session}}) do
    {:error, Failure.already_started()}
  end

  defp start_result({:error, {:journal_open_failed, error}}) do
    {:error, error}
  end

  defp start_result({:error, {:shutdown, {:journal_open_failed, error}}}) do
    {:error, error}
  end

  defp start_result({:error, _reason}) do
    {:error, Failure.start_failed()}
  end
end
