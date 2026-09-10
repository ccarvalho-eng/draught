defmodule Draught.Provider.Ollama.Execution.Recovery do
  @moduledoc """
  Retries one Ollama response that leaks a bare textual tool call.

  Recovery applies only when tools were offered. Exhausted recovery returns a
  normalized error without retaining the malformed assistant response.
  """

  alias Draught.Provider.Ollama.Protocol
  alias Draught.Provider.Ollama.Response.MalformedToolCall
  alias Draught.Provider.Request

  @max_attempts 2

  @doc "Runs an Ollama operation with one bounded malformed-call retry."
  @spec run(Request.t(), (-> Draught.Provider.provider_result(Draught.Provider.Response.t()))) ::
          Draught.Provider.provider_result(Draught.Provider.Response.t())
  def run(%Request{tools: []}, operation) when is_function(operation, 0) do
    operation.()
  end

  def run(%Request{tools: [_tool | _rest]}, operation) when is_function(operation, 0) do
    attempt(operation, 1)
  end

  defp attempt(operation, number) do
    result = operation.()
    handle_result(result, operation, number)
  end

  defp handle_result({:ok, response} = result, operation, number) do
    case MalformedToolCall.detect(response) do
      :ok -> result
      :malformed when number < @max_attempts -> attempt(operation, number + 1)
      :malformed -> Protocol.malformed_tool_call()
    end
  end

  defp handle_result({:error, _error} = result, _operation, _number) do
    result
  end
end
