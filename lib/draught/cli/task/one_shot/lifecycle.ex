defmodule Draught.CLI.Task.OneShot.Lifecycle do
  @moduledoc """
  Starts, runs, awaits, and stops the supervised session used by one-shot task execution.
  """

  alias Draught.CLI.Task.Approval.Prompt
  alias Draught.CLI.Task.Stream

  @wait_grace_ms 10_000

  @doc "Binds temporary-session options to the one-shot caller."
  @spec options(keyword(), pid(), Stream.t()) :: keyword()
  def options(session_options, owner, stream) do
    session_options
    |> interactive_timeout(stream)
    |> Keyword.put(
      :lifecycle,
      owner: owner,
      restart: :temporary
    )
  end

  @doc "Monitors a temporary session for terminal process exits."
  @spec monitor(pid()) :: reference()
  def monitor(session) do
    Process.monitor(session)
  end

  @doc "Returns the wrapper deadline derived from the validated session timeout."
  @spec wait_timeout(keyword()) :: timeout()
  def wait_timeout(options) do
    options
    |> Keyword.fetch!(:turn_timeout_ms)
    |> wait_timeout_value()
  end

  @doc "Stops a temporary session and releases its monitor."
  @spec stop(pid(), reference()) :: :ok
  def stop(session, monitor) do
    stop_session(session)
    Process.demonitor(monitor, [:flush])
    :ok
  end

  defp stop_session(session) do
    GenServer.stop(session, :normal, 5_000)
  catch
    :exit, _reason ->
      Process.exit(session, :kill)
      :ok
  end

  defp interactive_timeout(options, %Stream{approval: %Prompt{}}) do
    Keyword.put(options, :turn_timeout_ms, :infinity)
  end

  defp interactive_timeout(options, %Stream{}) do
    options
  end

  defp wait_timeout_value(:infinity) do
    :infinity
  end

  defp wait_timeout_value(timeout_ms) do
    timeout_ms + @wait_grace_ms
  end
end
