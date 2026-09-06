defmodule Draught.Tool do
  @moduledoc """
  Validates and executes provider-neutral tool calls through a registry.
  """

  alias Draught.Error.Normalized
  alias Draught.Tool.Call
  alias Draught.Tool.Execution.Context
  alias Draught.Tool.Execution.Invocation
  alias Draught.Tool.Registry

  @type execution_result :: {:ok, Draught.Tool.Result.t()} | {:error, Normalized.t()}

  @doc "Executes a tool call under an explicit workspace and policy context."
  @spec execute(Registry.t(), Call.t() | map() | keyword(), Context.t() | map() | keyword()) ::
          execution_result()
  def execute(%Registry{} = registry, call, context) do
    with {:ok, canonical_call} <- normalize_call(call),
         {:ok, canonical_context} <- normalize_context(context) do
      {:ok, Invocation.run(registry, canonical_call, canonical_context)}
    end
  end

  def execute(_registry, _call, _context) do
    configuration_error("invalid_tool_registry", "tool registry is invalid")
  end

  defp normalize_call(%Call{} = call) do
    call
    |> Map.from_struct()
    |> normalize_call()
  end

  defp normalize_call(call) do
    case Call.new(call) do
      {:ok, canonical} -> {:ok, canonical}
      {:error, _error} -> configuration_error("invalid_tool_call", "tool call is invalid")
    end
  end

  defp normalize_context(%Context{} = context) do
    context
    |> Map.from_struct()
    |> normalize_context()
  end

  defp normalize_context(context) do
    case Context.new(context) do
      {:ok, canonical} ->
        {:ok, canonical}

      {:error, _error} ->
        configuration_error("invalid_tool_context", "tool execution context is invalid")
    end
  end

  defp configuration_error(code, message) do
    {:ok, error} = Normalized.new(:configuration, code, message, retryable: false)
    {:error, error}
  end
end
