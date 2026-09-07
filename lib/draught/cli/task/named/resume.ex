defmodule Draught.CLI.Task.Named.Resume do
  @moduledoc """
  Reconstructs a safely resumable named session and executes its next durable task turn.
  """

  alias Draught.CLI.Session.Binding
  alias Draught.CLI.Session.Binding.Local
  alias Draught.CLI.Task.Named.History
  alias Draught.CLI.Task.Named.Lease
  alias Draught.CLI.Task.Named.Resume.Validation
  alias Draught.CLI.Task.OneShot
  alias Draught.CLI.Task.Preparation
  alias Draught.CLI.Task.Setup
  @doc "Resumes and executes one named turn through an explicit provider and stream mode."
  @spec run_mode(term(), term(), term(), term(), term(), term(), term(), :complete | :stream) ::
          {Draught.CLI.Task.result(), Draught.CLI.Task.Stream.t()}
  def run_mode(
        identifier,
        prompt,
        configuration,
        workspace,
        environment,
        dependencies,
        stream,
        provider_mode
      ) do
    case Lease.open(:resume, workspace, identifier, environment) do
      {:ok, store} ->
        Lease.run_observed(store, stream, fn ->
          execute(
            identifier,
            prompt,
            configuration,
            workspace,
            dependencies,
            store,
            stream,
            provider_mode
          )
        end)

      {:error, _category, _error} = result ->
        {result, stream}
    end
  end

  defp execute(
         identifier,
         prompt,
         configuration,
         workspace,
         dependencies,
         store,
         stream,
         provider_mode
       ) do
    with {:ok, binding, journal, replay} <- load(identifier, configuration, store),
         {:ok, preparation} <-
           prepare(
             prompt,
             binding.configuration,
             workspace,
             dependencies,
             replay,
             journal,
             provider_mode
           ),
         :ok <- Validation.verify(binding.value, replay, preparation),
         :ok <- upgrade(binding, preparation, store) do
      OneShot.run_observed(identifier, preparation, stream)
    else
      {:error, _category, _error} = result -> {result, stream}
    end
  end

  defp load(identifier, configuration, store) do
    with {:ok, binding} <- read_binding(store),
         {:ok, bound} <- bind_configuration(binding, configuration),
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

  defp read_binding(store) do
    case Local.read(store.paths) do
      {:ok, binding} -> {:ok, binding}
      {:error, error} -> {:error, :session, error}
    end
  end

  defp bind_configuration(binding, configuration) do
    case Binding.bind_configuration(binding, configuration) do
      {:ok, bound} -> {:ok, bound}
      {:error, error} -> {:error, :session, error}
    end
  end

  defp upgrade(%{value: %Binding{version: 2}}, %Preparation{}, _store) do
    :ok
  end

  defp upgrade(
         %{value: %Binding{version: 1}, configuration: configuration},
         %Preparation{} = preparation,
         store
       ) do
    upgraded = Binding.new(configuration, preparation)

    case Local.replace(store.paths, upgraded) do
      :ok -> :ok
      {:error, error} -> {:error, :session, error}
    end
  end
end
