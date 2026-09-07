defmodule Draught.Execution.Runner.BoundedTask do
  @moduledoc false

  alias Draught.Error.Normalized
  alias Draught.Execution.Runner.BoundedTask.OwnerGuard

  @doc "Runs one effect in the execution task supervisor with a fixed timeout."
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
