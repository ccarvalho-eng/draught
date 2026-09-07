defmodule Draught.Execution.Runner.Step.ProviderResult do
  @moduledoc """
  Performs and applies one provider step in the runner loop.

  The bounded provider result is emitted to the configured sink before it is
  accepted by the provider state transition.
  """

  alias Draught.Execution.Runner.Configuration
  alias Draught.Execution.Runner.ProviderExecution
  alias Draught.Execution.Runner.Sink
  alias Draught.Execution.Runner.State
  alias Draught.Execution.Runner.Transition.Provider
  alias Draught.Provider.Request
  alias Draught.Validation.Error

  @doc "Runs and applies one bounded provider completion."
  @spec run(Configuration.t(), State.t(), Request.t()) ::
          {:ok, State.t()} | {:error, Draught.Error.Normalized.t() | Error.t()}
  def run(configuration, state, request) do
    result = ProviderExecution.complete(configuration, request)

    with :ok <- Sink.emit(configuration.sink, {:provider_result, state.iteration, result}) do
      Provider.accept(state, result)
    end
  end
end
