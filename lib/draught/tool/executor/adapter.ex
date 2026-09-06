defmodule Draught.Tool.Executor.Adapter do
  @moduledoc false

  alias Draught.Validation.Error

  @doc "Validates an injected executor module and configuration."
  @spec validate(term()) :: Error.result({module(), term()})
  def validate({module, _configuration} = executor) when is_atom(module) do
    valid = Code.ensure_loaded?(module) and function_exported?(module, :execute, 3)
    result(valid, executor)
  end

  def validate(_executor) do
    invalid()
  end

  defp result(true, executor) do
    {:ok, executor}
  end

  defp result(false, _executor) do
    invalid()
  end

  defp invalid do
    Error.single([:executor], :invalid_value, "must implement the tool executor contract")
  end
end
