defmodule Draught.CLI.Task.Named.Resume.BindingState do
  @moduledoc """
  Reads, validates, and upgrades the provider binding for a resumed named task.
  """

  alias Draught.CLI.Configuration
  alias Draught.CLI.Session.Binding
  alias Draught.CLI.Session.Binding.Local
  alias Draught.CLI.Task.Preparation

  @doc "Reads a named-session binding through its validated store paths."
  @spec read(Draught.CLI.Session.Store.Handle.t()) ::
          {:ok, Binding.t()} | {:error, :session, Draught.CLI.Task.error()}
  def read(store) do
    case Local.read(store.paths) do
      {:ok, binding} -> {:ok, binding}
      {:error, error} -> {:error, :session, error}
    end
  end

  @doc "Applies the durable binding to the current CLI configuration."
  @spec bind_configuration(Binding.t(), Configuration.t()) ::
          {:ok, Configuration.t()} | {:error, :session, Draught.CLI.Task.error()}
  def bind_configuration(binding, configuration) do
    case Binding.bind_configuration(binding, configuration) do
      {:ok, bound} -> {:ok, bound}
      {:error, error} -> {:error, :session, error}
    end
  end

  @doc "Upgrades a verified legacy binding or keeps the current representation."
  @spec upgrade(map(), Preparation.t(), Draught.CLI.Session.Store.Handle.t()) ::
          :ok | {:error, :session, Draught.CLI.Task.error()}
  def upgrade(%{value: %Binding{version: 2}}, %Preparation{}, _store) do
    :ok
  end

  def upgrade(
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
