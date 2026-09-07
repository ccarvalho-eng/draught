defmodule Draught.Tool.Approval.Policy.Adapter do
  @moduledoc """
  Validates the module and configuration used as an approval policy.

  The adapter accepts only loaded modules that implement the required
  `decide/2` callback and returns a normalized configuration failure otherwise.
  """

  alias Draught.Error.Normalized

  @doc "Validates an injected approval policy module and configuration."
  @spec validate(term()) :: {:ok, module(), term()} | {:error, Normalized.t()}
  def validate({module, configuration}) when is_atom(module) do
    valid = Code.ensure_loaded?(module) and function_exported?(module, :decide, 2)
    result(valid, module, configuration)
  end

  def validate(_policy) do
    invalid()
  end

  defp result(true, module, configuration) do
    {:ok, module, configuration}
  end

  defp result(false, _module, _configuration) do
    invalid()
  end

  defp invalid do
    {:ok, error} =
      Normalized.new(
        :configuration,
        "invalid_approval_policy",
        "approval policy is invalid",
        retryable: false
      )

    {:error, error}
  end
end
