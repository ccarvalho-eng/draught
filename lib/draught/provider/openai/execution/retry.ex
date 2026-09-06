defmodule Draught.Provider.OpenAI.Execution.Retry do
  @moduledoc """
  Runs a bounded provider attempt loop with a fixed delay policy.
  """

  alias Draught.Error.Normalized
  alias Draught.Provider.OpenAI.Configuration.Retry

  @type attempt_result(value) ::
          {:ok, value} | {:error, Normalized.t(), output_emitted :: boolean()}

  @doc "Runs attempts until success or a failure that must not be retried."
  @spec run(Retry.t(), (-> attempt_result(value))) ::
          {:ok, value} | {:error, Normalized.t()}
        when value: term()
  def run(%Retry{} = policy, attempt) when is_function(attempt, 0) do
    run_attempt(policy, attempt, 1)
  end

  defp run_attempt(policy, attempt, number) do
    case attempt.() do
      {:ok, value} ->
        {:ok, value}

      {:error, %Normalized{} = error, output_emitted} ->
        retry = error.retryable and not output_emitted and number < policy.max_attempts
        retry_result(retry, policy, attempt, number, error)
    end
  end

  defp retry_result(true, policy, attempt, number, _error) do
    wait(policy.fixed_delay_ms)
    run_attempt(policy, attempt, number + 1)
  end

  defp retry_result(false, _policy, _attempt, _number, error) do
    {:error, error}
  end

  defp wait(0) do
    :ok
  end

  defp wait(milliseconds) do
    Process.sleep(milliseconds)
  end
end
