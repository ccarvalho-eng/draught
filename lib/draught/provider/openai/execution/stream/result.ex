defmodule Draught.Provider.OpenAI.Execution.Stream.Result do
  @moduledoc false

  alias Draught.Error.Normalized
  alias Draught.Provider.OpenAI.Execution.Stream.State
  alias Draught.Provider.OpenAI.Failure.Normalizer
  alias Draught.Provider.OpenAI.Protocol
  alias Draught.Provider.OpenAI.Stream.Accumulator
  alias Draught.Provider.OpenAI.Stream.SSE
  alias Draught.Provider.OpenAI.Transport.Failure
  alias Draught.Provider.OpenAI.Transport.Response

  @doc "Normalizes and finalizes one streaming transport result."
  @spec normalize(term()) :: Draught.Provider.OpenAI.Execution.Retry.attempt_result(term())
  def normalize({:ok, %Response{status: status}, %State{} = state})
      when status >= 200 and status <= 299 do
    finalize(state)
  end

  def normalize({:ok, %Response{status: status}, %State{}}) when is_integer(status) do
    {:error, Normalizer.http(status), false}
  end

  def normalize({:error, %Failure{} = failure, output_emitted})
      when is_boolean(output_emitted) do
    {:error, Normalizer.transport(failure), output_emitted}
  end

  def normalize(_result) do
    protocol_attempt(
      "invalid_transport_result",
      "OpenAI transport returned an invalid result",
      false
    )
  end

  defp finalize(%State{error: %Normalized{} = error} = state) do
    {:error, error, State.output?(state)}
  end

  defp finalize(%State{} = state) do
    with :ok <- SSE.finish(state.sse),
         {:ok, response} <- Accumulator.finish(state.accumulator) do
      {:ok, response}
    else
      {:error, error} -> {:error, error, State.output?(state)}
    end
  end

  defp protocol_attempt(code, message, output_emitted) do
    {:error, error} = Protocol.error(code, message)
    {:error, error, output_emitted}
  end
end
