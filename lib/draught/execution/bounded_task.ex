defmodule Draught.Execution.BoundedTask do
  @moduledoc """
  Runs one effect under the execution task supervisor with a fixed deadline.

  The boundary converts task exits and timeouts into caller-supplied normalized
  failures and ensures the task is terminated if its owner dies.
  """

  alias Draught.Error.Normalized
  alias Draught.Execution.BoundedTask.OwnerGuard

  @doc "Runs one supervised effect with a fixed timeout and owner-death cleanup."
  @spec run((-> term()), pos_integer(), Normalized.t(), Normalized.t()) :: term()
  def run(effect, timeout_ms, timeout_error, crash_error) when is_function(effect, 0) do
    owner = self()
    guarded_effect = fn -> run_guarded(owner, effect) end
    task = Task.Supervisor.async_nolink(Draught.Execution.TaskSupervisor, guarded_effect)

    case Task.yield(task, timeout_ms) do
      {:ok, result} -> result
      {:exit, _reason} -> {:error, crash_error}
      nil -> timeout(task, timeout_error)
    end
  end

  defp timeout(task, error) do
    Task.shutdown(task, :brutal_kill)
    {:error, error}
  end

  defp run_guarded(owner, effect) do
    :ok = OwnerGuard.protect(owner)
    effect.()
  end
end
