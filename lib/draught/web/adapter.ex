defmodule Draught.Web.Adapter do
  @moduledoc false

  alias Draught.Validation.Error

  @doc "Validates an adapter tuple for one web operation."
  @spec validate(term(), :fetch | :search) :: Error.result({module(), term()})
  def validate({module, _configuration} = adapter, operation) when is_atom(module) do
    operation
    |> callback()
    |> exported?(module)
    |> result(adapter, operation)
  end

  def validate(_adapter, operation) do
    invalid(operation)
  end

  defp callback(:search) do
    {:search, 3}
  end

  defp callback(:fetch) do
    {:fetch, 3}
  end

  defp exported?({function, arity}, module) do
    Code.ensure_loaded?(module) and function_exported?(module, function, arity)
  end

  defp result(true, adapter, _operation) do
    {:ok, adapter}
  end

  defp result(false, _adapter, operation) do
    invalid(operation)
  end

  defp invalid(operation) do
    Error.single(
      [operation],
      :invalid_value,
      "must implement the web #{operation} adapter contract"
    )
  end
end
