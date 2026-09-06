defmodule Draught.Provider.Adapter do
  @moduledoc false

  alias Draught.Error.Normalized

  @required_callbacks [capabilities: 1, complete: 2, stream: 3]

  @doc false
  @spec validate(term()) :: {:ok, module(), term()} | {:error, Normalized.t()}
  def validate({module, config}) when is_atom(module) do
    valid? = Code.ensure_loaded?(module) and callbacks_exported?(module)
    validation_result(valid?, module, config)
  end

  def validate(_adapter) do
    configuration_error("adapter must be a {module, config} tuple")
  end

  defp callbacks_exported?(module) do
    Enum.all?(@required_callbacks, fn {function, arity} ->
      function_exported?(module, function, arity)
    end)
  end

  defp validation_result(true, module, config) do
    {:ok, module, config}
  end

  defp validation_result(false, _module, _config) do
    configuration_error("adapter does not implement the provider contract")
  end

  defp configuration_error(message) do
    {:ok, error} =
      Normalized.new(:configuration, "invalid_configuration", message, retryable: false)

    {:error, error}
  end
end
