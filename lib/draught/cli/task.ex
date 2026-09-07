defmodule Draught.CLI.Task do
  @moduledoc """
  Prepares and executes one bounded coding-agent task without terminal concerns.
  """

  alias Draught.CLI.Configuration
  alias Draught.CLI.Task.Dependencies
  alias Draught.CLI.Task.Failure
  alias Draught.CLI.Task.OneShot
  alias Draught.CLI.Task.Preparation
  alias Draught.CLI.Task.Provider

  @type error :: Draught.Error.Normalized.t() | Draught.Validation.Error.t()
  @type result :: {:ok, Draught.Provider.Response.t()} | {:error, atom(), error()}

  @doc "Runs one anonymous task through the provider and supervised session boundaries."
  @spec run(String.t(), Configuration.t(), String.t(), Dependencies.t()) :: result()
  def run(prompt, %Configuration{} = configuration, workspace, %Dependencies{} = dependencies) do
    with :ok <- web(configuration),
         {:ok, selection} <- provider(configuration, dependencies),
         {:ok, preparation} <-
           prepare(prompt, selection, workspace, configuration),
         {:ok, identifier} <- identifier(dependencies) do
      OneShot.run(identifier, preparation)
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

  defp prepare(prompt, selection, workspace, configuration) do
    case Preparation.new(
           prompt,
           selection,
           workspace,
           risk: configuration.risk,
           web: configuration.web
         ) do
      {:ok, preparation} -> {:ok, preparation}
      {:error, error} -> {:error, :execution, error}
    end
  end

  defp identifier(%Dependencies{identifier: generator}) do
    case generator.() do
      {:ok, identifier} when is_binary(identifier) -> {:ok, identifier}
      _result -> {:error, :session, Failure.invalid_identifier()}
    end
  end
end
