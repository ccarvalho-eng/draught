defmodule Draught.Provider.OpenAI.Execution.Stream.Attempt do
  @moduledoc false

  alias Draught.Provider.OpenAI.Execution.Stream.Reducer
  alias Draught.Provider.OpenAI.Execution.Stream.Result
  alias Draught.Provider.OpenAI.Execution.Stream.State
  alias Draught.Provider.OpenAI.Runtime
  alias Draught.Provider.OpenAI.Transport.Dispatch

  @doc "Executes one isolated streaming attempt."
  @spec run(Runtime.t(), Draught.Provider.OpenAI.Transport.Request.t(), function()) ::
          Draught.Provider.OpenAI.Execution.Retry.attempt_result(term())
  def run(%Runtime{} = runtime, request, sink) do
    case State.new(runtime.configuration.limits) do
      {:ok, initial} -> execute(runtime, request, initial, sink)
      {:error, error} -> {:error, error, false}
    end
  end

  defp execute(runtime, request, initial, sink) do
    reducer = fn data, state -> Reducer.reduce(data, state, sink) end

    runtime
    |> Dispatch.stream(request, initial, reducer)
    |> Result.normalize()
  end
end
