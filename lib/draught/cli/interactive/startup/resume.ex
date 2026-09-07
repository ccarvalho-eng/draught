defmodule Draught.CLI.Interactive.Startup.Resume do
  @moduledoc """
  Loads and applies a durable session binding before interactive provider selection.

  The session lease prevents concurrent binding changes during the read. Normal
  named resume performs the same validation again before executing a turn.
  """

  alias Draught.CLI.Command.Invocation
  alias Draught.CLI.Configuration
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Session.Binding
  alias Draught.CLI.Session.Binding.Local
  alias Draught.CLI.Task.Named.Lease

  @doc "Applies a recorded resume model or leaves new-session configuration unchanged."
  @spec bind(Invocation.t(), Configuration.t(), String.t(), String.t(), Dependencies.t()) ::
          {:ok, Configuration.t()} | {:error, :session, term()}
  def bind(
        %Invocation{resume: resume},
        configuration,
        workspace,
        identifier,
        dependencies
      )
      when is_binary(resume) do
    environment = environment(dependencies.system)

    case Lease.open(:resume, workspace, identifier, environment) do
      {:ok, store} -> bind_opened(store, configuration)
      {:error, :session, error} -> {:error, :session, error}
    end
  end

  def bind(%Invocation{}, configuration, _workspace, _identifier, _dependencies) do
    {:ok, configuration}
  end

  defp bind_opened(store, configuration) do
    result =
      Lease.run_opened(store, fn ->
        with {:ok, binding} <- Local.read(store.paths) do
          Binding.bind_configuration(binding, configuration)
        end
      end)

    bind_opened_result(result)
  end

  defp bind_opened_result({:ok, configuration}) do
    {:ok, configuration}
  end

  defp bind_opened_result({:error, :session, error}) do
    {:error, :session, error}
  end

  defp bind_opened_result({:error, error}) do
    {:error, :session, error}
  end

  defp environment({system, configuration}) do
    system.environment(configuration)
  end
end
