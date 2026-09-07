defmodule Draught.CLI.Task.Setup do
  @moduledoc """
  Prepares provider, request, tools, and limits while retaining CLI failure categories.
  """

  alias Draught.CLI.Configuration
  alias Draught.CLI.Task.Dependencies
  alias Draught.CLI.Task.Failure
  alias Draught.CLI.Task.Preparation
  alias Draught.CLI.Task.Provider

  @doc "Prepares one task while retaining categorized setup failures."
  @spec prepare(String.t(), Configuration.t(), String.t(), Dependencies.t(), keyword()) ::
          {:ok, Preparation.t()} | {:error, atom(), Draught.CLI.Task.error()}
  def prepare(prompt, configuration, workspace, dependencies, options \\ []) do
    with :ok <- web(configuration),
         {:ok, selection} <- provider(configuration, dependencies) do
      build_preparation(prompt, selection, workspace, configuration, options)
    end
  end

  defp web(%Configuration{web: false}) do
    :ok
  end

  defp web(%Configuration{web: true}) do
    {:error, :execution, Failure.web_unavailable()}
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
