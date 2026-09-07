defmodule Draught.CLI.Task do
  @moduledoc """
  Prepares and executes one bounded coding-agent task without terminal concerns.
  """

  alias Draught.CLI.Task.Dependencies
  alias Draught.CLI.Task.Failure
  alias Draught.CLI.Task.OneShot
  alias Draught.CLI.Task.Setup

  @type error :: Draught.Error.Normalized.t() | Draught.Validation.Error.t()
  @type result :: {:ok, Draught.Provider.Response.t()} | {:error, atom(), error()}

  @doc "Runs one anonymous task through the provider and supervised session boundaries."
  @spec run(String.t(), Draught.CLI.Configuration.t(), String.t(), Dependencies.t()) :: result()
  def run(prompt, configuration, workspace, %Dependencies{} = dependencies) do
    with {:ok, preparation} <- Setup.prepare(prompt, configuration, workspace, dependencies),
         {:ok, identifier} <- identifier(dependencies) do
      OneShot.run(identifier, preparation)
    end
  end

  defp identifier(%Dependencies{identifier: generator}) do
    case generator.() do
      {:ok, identifier} when is_binary(identifier) -> {:ok, identifier}
      _result -> {:error, :session, Failure.invalid_identifier()}
    end
  end
end
