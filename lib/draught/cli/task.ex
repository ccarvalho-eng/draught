defmodule Draught.CLI.Task do
  @moduledoc """
  Prepares and executes one bounded coding-agent task through an injected stream observer.
  """

  alias Draught.CLI.Task.Dependencies
  alias Draught.CLI.Task.Failure
  alias Draught.CLI.Task.OneShot
  alias Draught.CLI.Task.Setup
  alias Draught.CLI.Task.Stream

  @type error :: Draught.Error.Normalized.t() | Draught.Validation.Error.t()
  @type result :: {:ok, Draught.Provider.Response.t()} | {:error, atom(), error()}

  @doc "Runs one anonymous task through the provider and supervised session boundaries."
  @spec run(String.t(), Draught.CLI.Configuration.t(), String.t(), Dependencies.t()) :: result()
  def run(prompt, configuration, workspace, %Dependencies{} = dependencies) do
    {result, _stream} =
      execute(prompt, configuration, workspace, dependencies, Stream.silent(), :complete)

    result
  end

  @doc "Runs one anonymous task while threading an ordered CLI stream observer."
  @spec run_observed(
          String.t(),
          Draught.CLI.Configuration.t(),
          String.t(),
          Dependencies.t(),
          Stream.t()
        ) :: {result(), Stream.t()}
  def run_observed(prompt, configuration, workspace, %Dependencies{} = dependencies, stream) do
    execute(prompt, configuration, workspace, dependencies, stream, :stream)
  end

  defp execute(prompt, configuration, workspace, dependencies, stream, provider_mode) do
    with {:ok, preparation} <-
           Setup.prepare(prompt, configuration, workspace, dependencies,
             provider_mode: provider_mode
           ),
         {:ok, identifier} <- identifier(dependencies) do
      OneShot.run_observed(identifier, preparation, stream)
    else
      {:error, _category, _error} = result -> {result, stream}
    end
  end

  defp identifier(%Dependencies{identifier: generator}) do
    case generator.() do
      {:ok, identifier} when is_binary(identifier) -> {:ok, identifier}
      _result -> {:error, :session, Failure.invalid_identifier()}
    end
  end
end
