defmodule Draught.CLI.Interactive.Terminal.SmartShell do
  @moduledoc """
  Runs the operating-system prompt inside OTP's supervised terminal editor.

  Native and escript entry points start without an Erlang shell. This bridge
  establishes the documented OTP line editor, transfers the prompt worker to
  its I/O group, and waits for one bounded CLI result. The worker remains alive
  until the entry-point process exits so OTP does not replace Draught's closing
  output with a job-control prompt.
  """

  alias Draught.CLI.Command.ExitStatus

  @internal_status ExitStatus.value(:internal)

  @doc "Runs an interactive entry-point operation through OTP's smart terminal when available."
  @spec run((-> non_neg_integer())) :: non_neg_integer()
  def run(operation) when is_function(operation, 0) do
    run(operation, :shell, Draught.Execution.TaskSupervisor)
  end

  @doc "Starts the supervised prompt worker requested by OTP's custom-shell boundary."
  @spec start(pid(), reference(), (-> non_neg_integer()), Supervisor.supervisor()) :: pid()
  def start(parent, reference, operation, supervisor)
      when is_pid(parent) and is_reference(reference) and is_function(operation, 0) do
    group_leader = Process.group_leader()

    case Task.Supervisor.start_child(supervisor, fn ->
           worker(parent, reference, operation, group_leader)
         end) do
      {:ok, worker} ->
        send(parent, {:draught_smart_shell, reference, :started, worker})
        worker

      {:error, _reason} ->
        failure_worker(parent, reference)
    end
  end

  @doc false
  @spec run((-> non_neg_integer()), module(), Supervisor.supervisor()) :: non_neg_integer()
  def run(operation, shell, supervisor)
      when is_function(operation, 0) and is_atom(shell) do
    parent = self()
    reference = make_ref()
    callback = {__MODULE__, :start, [parent, reference, operation, supervisor]}

    shell
    |> start_shell(callback)
    |> await_or_fallback(operation, reference)
  end

  defp start_shell(shell, callback) do
    with_slogans(fn -> shell.start_interactive(callback) end)
  catch
    :exit, _reason -> {:error, :unavailable}
  end

  defp await_or_fallback(:ok, _operation, reference) do
    await_started(reference)
  end

  defp await_or_fallback({:error, _reason}, operation, _reference) do
    operation.()
  end

  defp await_or_fallback(_result, _operation, _reference) do
    @internal_status
  end

  defp await_started(reference) do
    receive do
      {:draught_smart_shell, ^reference, :started, worker} when is_pid(worker) ->
        await_result(reference, worker, Process.monitor(worker))

      {:draught_smart_shell, ^reference, :failed} ->
        @internal_status
    end
  end

  defp await_result(reference, worker, monitor) do
    receive do
      {:draught_smart_shell, ^reference, :result, status} when is_integer(status) ->
        Process.demonitor(monitor, [:flush])
        status

      {:DOWN, ^monitor, :process, ^worker, _reason} ->
        @internal_status
    end
  end

  defp worker(parent, reference, operation, group_leader) do
    parent_monitor = Process.monitor(parent)
    true = Process.group_leader(self(), group_leader)
    status = operation.()
    send(parent, {:draught_smart_shell, reference, :result, status})

    receive do
      {:DOWN, ^parent_monitor, :process, ^parent, _reason} -> :ok
    end
  end

  defp failure_worker(parent, reference) do
    spawn(fn -> send(parent, {:draught_smart_shell, reference, :failed}) end)
  end

  defp with_slogans(operation) do
    shell_slogan = Application.get_env(:stdlib, :shell_slogan, :missing)
    session_slogan = Application.get_env(:stdlib, :shell_session_slogan, :missing)
    Application.put_env(:stdlib, :shell_slogan, "")
    Application.put_env(:stdlib, :shell_session_slogan, "")

    try do
      operation.()
    after
      restore_environment(:shell_slogan, shell_slogan)
      restore_environment(:shell_session_slogan, session_slogan)
    end
  end

  defp restore_environment(key, :missing) do
    Application.delete_env(:stdlib, key)
  end

  defp restore_environment(key, value) do
    Application.put_env(:stdlib, key, value)
  end
end
