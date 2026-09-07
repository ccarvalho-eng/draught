defmodule Draught.Execution.Runner.BoundedTask do
  @moduledoc false

  alias Draught.Error.Normalized

  @doc "Runs one effect in the execution task supervisor with a fixed timeout."
  @spec run((-> term()), pos_integer(), Normalized.t(), Normalized.t()) :: term()
  def run(effect, timeout_ms, timeout_error, crash_error) when is_function(effect, 0) do
    task = Task.Supervisor.async_nolink(Draught.Execution.TaskSupervisor, effect)

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
end
