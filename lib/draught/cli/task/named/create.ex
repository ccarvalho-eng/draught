defmodule Draught.CLI.Task.Named.Create do
  @moduledoc false

  alias Draught.CLI.Session.Binding
  alias Draught.CLI.Session.Binding.Local
  alias Draught.CLI.Task.Named.History
  alias Draught.CLI.Task.Named.Lease
  alias Draught.CLI.Task.OneShot
  alias Draught.CLI.Task.Setup

  @doc "Creates and executes one named session turn."
  @spec run(term(), term(), term(), term(), term(), term()) :: Draught.CLI.Task.result()
  def run(identifier, prompt, configuration, workspace, environment, dependencies) do
    with {:ok, preparation} <- Setup.prepare(prompt, configuration, workspace, dependencies),
         {:ok, store} <- Lease.open(:create, workspace, identifier, environment) do
      Lease.run_opened(store, fn ->
        initialize(identifier, configuration, preparation, store)
      end)
    end
  end

  defp initialize(identifier, configuration, preparation, store) do
    binding = Binding.new(configuration, preparation)

    case Local.create(store.paths, binding) do
      :ok -> execute(identifier, preparation, store)
      {:error, error} -> Lease.abort(store, error)
    end
  end

  defp execute(identifier, preparation, store) do
    with {:ok, journal} <- History.journal(identifier, store) do
      preparation
      |> History.attach(journal)
      |> then(&OneShot.run(identifier, &1))
    end
  end
end
