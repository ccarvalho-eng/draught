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
  alias Draught.CLI.Task.Setup

  @doc "Resumes and executes one named session turn."
  @spec run(term(), term(), term(), term(), term(), term()) :: Draught.CLI.Task.result()
  def run(identifier, prompt, configuration, workspace, environment, dependencies) do
    with {:ok, store} <- Lease.open(:resume, workspace, identifier, environment) do
      Lease.run_opened(store, fn ->
        execute(identifier, prompt, configuration, workspace, dependencies, store)
      end)
    end
  end

  defp execute(identifier, prompt, configuration, workspace, dependencies, store) do
    with {:ok, binding, journal, replay} <- load(identifier, configuration, store),
         {:ok, preparation} <-
           prepare(prompt, binding.configuration, workspace, dependencies, replay, journal),
         :ok <- Validation.verify(binding.value, replay, preparation) do
      OneShot.run(identifier, preparation)
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

  defp prepare(prompt, configuration, workspace, dependencies, replay, journal) do
    Setup.prepare(prompt, configuration, workspace, dependencies,
      history: replay.messages,
      journal: journal
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
end
