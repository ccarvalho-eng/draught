defmodule Draught.CLI.Task.Setup do
  @moduledoc """
  Prepares provider, request, tools, and limits while retaining CLI failure categories.

  An injected task approval policy takes precedence over a preparation option.
  Without that dependency, explicit options and risk-derived defaults retain
  their existing behavior. Risk and web authority always come from configuration.
  """

  alias Draught.CLI.Configuration
  alias Draught.CLI.Task.Dependencies
  alias Draught.CLI.Task.Preparation
  alias Draught.CLI.Task.Provider

  @doc "Prepares one task while retaining categorized setup failures."
  @spec prepare(String.t(), Configuration.t(), String.t(), Dependencies.t(), keyword()) ::
          {:ok, Preparation.t()} | {:error, atom(), Draught.CLI.Task.error()}
  def prepare(prompt, configuration, workspace, dependencies, options \\ []) do
    options = approval_options(options, dependencies.approval)

    with {:ok, selection} <- provider(configuration, dependencies) do
      build_preparation(prompt, selection, workspace, configuration, options)
    end
  end

  @doc "Returns the built-in system instruction used when no fresh-task override is supplied."
  @spec system_prompt() :: String.t()
  def system_prompt do
    Preparation.system_prompt()
  end

  defp approval_options(options, nil) do
    options
  end

  defp approval_options(options, policy) do
    Keyword.put(options, :approval, policy)
  end

  defp provider(configuration, dependencies) do
    case Provider.build(configuration, dependencies.provider) do
      {:ok, selection} -> {:ok, selection}
      {:error, error} -> {:error, :provider, error}
    end
  end

  defp build_preparation(prompt, selection, workspace, configuration, options) do
    preparation_options =
      options
      |> Keyword.put(:risk, configuration.risk)
      |> Keyword.put(:web, configuration.web)

    case Preparation.new(prompt, selection, workspace, preparation_options) do
      {:ok, preparation} -> {:ok, preparation}
      {:error, error} -> {:error, :execution, error}
    end
  end
end
