defmodule Draught.CLI.Interactive.Inspection.Command do
  @moduledoc """
  Resolves read-only interactive inspection commands through pure projections.

  Inspection never starts a provider request, executes a tool, or mutates the
  active configuration.
  """

  alias Draught.CLI.Configuration
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Interactive.Inspection.Permissions
  alias Draught.CLI.Interactive.Inspection.ToolCatalog
  alias Draught.CLI.Interactive.State
  alias Draught.Validation.Error

  @type view :: {:permissions, Permissions.t()} | {:tools, ToolCatalog.t()}
  @type result :: {:ok, view()} | {:error, Error.t() | :invalid_command}

  @doc "Builds the requested non-secret inspection view without performing effects."
  @spec run(:permissions | :tools, State.t(), Configuration.t(), Dependencies.t()) :: result()
  def run(:permissions, %State{} = state, %Configuration{} = configuration, dependencies) do
    case Permissions.build(state, configuration, dependencies) do
      {:ok, permissions} -> {:ok, {:permissions, permissions}}
      {:error, %Error{}} = error -> error
    end
  end

  def run(:tools, %State{}, %Configuration{} = configuration, %Dependencies{}) do
    case ToolCatalog.build(configuration) do
      {:ok, catalog} -> {:ok, {:tools, catalog}}
      {:error, %Error{}} = error -> error
    end
  end

  def run(_command, %State{}, %Configuration{}, %Dependencies{}) do
    {:error, :invalid_command}
  end
end
