defmodule Draught.CLI.Task.Named.Create do
  @moduledoc """
  Creates a bound named session and executes its first durable task turn.
  """

  alias Draught.CLI.Task.Named.Create.Initialization
  alias Draught.CLI.Task.Named.History
  alias Draught.CLI.Task.Named.Input
  alias Draught.CLI.Task.Named.Lease
  alias Draught.CLI.Task.Named.Preview.Recorder
  alias Draught.CLI.Task.OneShot
  alias Draught.CLI.Task.Setup

  @doc "Creates and executes one named turn through an explicit provider and stream mode."
  @spec run_mode(Input.t(), Draught.CLI.Task.Stream.t(), :complete | :stream) ::
          {Draught.CLI.Task.result(), Draught.CLI.Task.Stream.t()}
  def run_mode(%Input{} = input, stream, provider_mode) do
    with {:ok, preparation} <-
           Setup.prepare(
             input.prompt,
             input.configuration,
             input.workspace,
             input.dependencies,
             provider_mode: provider_mode,
             system_prompt: input.system_prompt
           ),
         {:ok, store} <-
           Lease.open(:create, input.workspace, input.identifier, input.environment) do
      Lease.run_observed(store, stream, fn ->
        initialize(input, preparation, store, stream)
      end)
    else
      {:error, _category, _error} = result -> {result, stream}
    end
  end

  defp initialize(input, preparation, store, stream) do
    case Initialization.persist(input, preparation, store) do
      :ok -> execute(input, preparation, store, stream)
      {:error, error} -> {Lease.abort(store, error), stream}
    end
  end

  defp execute(input, preparation, store, stream) do
    case History.journal(input.identifier, store) do
      {:ok, journal} ->
        preparation
        |> History.attach(journal)
        |> then(&OneShot.run_observed(input.identifier, &1, stream))
        |> Recorder.record(store.paths, input.prompt)

      {:error, _category, _error} = result ->
        {result, stream}
    end
  end
end
