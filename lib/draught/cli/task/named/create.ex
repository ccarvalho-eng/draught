defmodule Draught.CLI.Task.Named.Create do
  @moduledoc """
  Creates a bound named session and executes its first durable task turn.
  """

  alias Draught.CLI.Session.Binding
  alias Draught.CLI.Session.Binding.Local
  alias Draught.CLI.Task.Named.History
  alias Draught.CLI.Task.Named.Lease
  alias Draught.CLI.Task.OneShot
  alias Draught.CLI.Task.Setup
  @doc "Creates and executes one named turn through an explicit provider and stream mode."
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
    with {:ok, preparation} <-
           Setup.prepare(prompt, configuration, workspace, dependencies,
             provider_mode: provider_mode
           ),
         {:ok, store} <- Lease.open(:create, workspace, identifier, environment) do
      Lease.run_observed(store, stream, fn ->
        initialize(identifier, configuration, preparation, store, stream)
      end)
    else
      {:error, _category, _error} = result -> {result, stream}
    end
  end

  defp initialize(identifier, configuration, preparation, store, stream) do
    binding = Binding.new(configuration, preparation)

    case Local.create(store.paths, binding) do
      :ok -> execute(identifier, preparation, store, stream)
      {:error, error} -> {Lease.abort(store, error), stream}
    end
  end

  defp execute(identifier, preparation, store, stream) do
    case History.journal(identifier, store) do
      {:ok, journal} ->
        preparation
        |> History.attach(journal)
        |> then(&OneShot.run_observed(identifier, &1, stream))

      {:error, _category, _error} = result ->
        {result, stream}
    end
  end
end
