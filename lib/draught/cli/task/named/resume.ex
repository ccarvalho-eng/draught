defmodule Draught.CLI.Task.Named.Resume do
  @moduledoc """
  Reconstructs a safely resumable named session and executes its next durable task turn.
  """

  alias Draught.CLI.Task.Named.History
  alias Draught.CLI.Task.Named.Input
  alias Draught.CLI.Task.Named.Lease
  alias Draught.CLI.Task.Named.Preview.Recorder
  alias Draught.CLI.Task.Named.Resume.BindingState
  alias Draught.CLI.Task.Named.Resume.Validation
  alias Draught.CLI.Task.OneShot
  alias Draught.CLI.Task.Setup

  @doc "Resumes and executes one named turn through an explicit provider and stream mode."
  @spec run_mode(Input.t(), Draught.CLI.Task.Stream.t(), :complete | :stream) ::
          {Draught.CLI.Task.result(), Draught.CLI.Task.Stream.t()}
  def run_mode(%Input{} = input, stream, provider_mode) do
    case Lease.open(:resume, input.workspace, input.identifier, input.environment) do
      {:ok, store} ->
        Lease.run_observed(store, stream, fn ->
          execute(input, store, stream, provider_mode)
        end)

      {:error, _category, _error} = result ->
        {result, stream}
    end
  end

  defp execute(input, store, stream, provider_mode) do
    with {:ok, binding, journal, replay} <-
           load(input.identifier, input.configuration, store),
         {:ok, preparation} <-
           prepare(
             input.prompt,
             binding.configuration,
             input.workspace,
             input.dependencies,
             replay,
             journal,
             provider_mode
           ),
         :ok <- Validation.verify(binding.value, replay, preparation),
         :ok <- BindingState.upgrade(binding, preparation, store) do
      input.identifier
      |> OneShot.run_observed(preparation, stream)
      |> Recorder.record(store.paths, input.prompt)
    else
      {:error, _category, _error} = result -> {result, stream}
    end
  end

  defp load(identifier, configuration, store) do
    with {:ok, binding} <- BindingState.read(store),
         {:ok, bound} <- BindingState.bind_configuration(binding, configuration),
         {:ok, journal} <- History.journal(identifier, store),
         {:ok, replay} <- History.replay(journal),
         :ok <- Validation.resumable(replay) do
      {:ok, %{value: binding, configuration: bound}, journal, replay}
    end
  end

  defp prepare(
         prompt,
         configuration,
         workspace,
         dependencies,
         replay,
         journal,
         provider_mode
       ) do
    Setup.prepare(prompt, configuration, workspace, dependencies,
      history: replay.messages,
      journal: journal,
      provider_mode: provider_mode
    )
  end
end
