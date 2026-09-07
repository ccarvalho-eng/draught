defmodule Draught.Execution.Runner.Loop do
  @moduledoc """
  Drives runner state transitions until the run reaches a terminal outcome.

  Provider and tool effects occur only through their bounded execution
  modules, while terminal outcomes are delivered through the configured sink.
  """

  alias Draught.Error.Normalized
  alias Draught.Execution.Runner.Configuration
  alias Draught.Execution.Runner.Sink
  alias Draught.Execution.Runner.State
  alias Draught.Execution.Runner.Step.ProviderResult
  alias Draught.Execution.Runner.Step.Tools
  alias Draught.Execution.Runner.Transition
  alias Draught.Validation.Error

  @doc "Runs state transitions and effects until one terminal outcome."
  @spec run(Configuration.t(), State.t()) ::
          {:ok, Draught.Provider.Response.t()} | {:error, Normalized.t() | Error.t()}
  def run(configuration, state) do
    case Transition.next_request(state) do
      {:continue, waiting, request} -> provider(configuration, waiting, request)
      {:halt, terminal} -> finish(configuration, terminal)
      {:error, %Error{}} = result -> result
    end
  end

  defp provider(configuration, state, request) do
    with {:ok, next} <- ProviderResult.run(configuration, state, request) do
      continue(configuration, next)
    end
  end

  defp continue(configuration, %State{status: :waiting_tools} = state) do
    with {:ok, ready} <- Tools.run(configuration, state) do
      run(configuration, ready)
    end
  end

  defp continue(configuration, %State{} = state) do
    run(configuration, state)
  end

  defp finish(configuration, state) do
    outcome = State.outcome(state)

    with :ok <- Sink.emit(configuration.sink, {:terminal, outcome}) do
      outcome
    end
  end
end
