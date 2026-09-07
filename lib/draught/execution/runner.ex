defmodule Draught.Execution.Runner do
  @moduledoc """
  Executes a bounded provider-tool loop from explicitly injected dependencies.
  """

  alias Draught.Error.Normalized
  alias Draught.Execution.Runner.Configuration
  alias Draught.Execution.Runner.Loop
  alias Draught.Execution.Runner.Request
  alias Draught.Execution.Runner.State
  alias Draught.Validation.Error

  @type result :: {:ok, Draught.Provider.Response.t()} | {:error, Normalized.t() | Error.t()}

  @doc "Runs a request until a final response or bounded terminal failure."
  @spec run(
          Configuration.t() | map() | keyword(),
          Draught.Provider.Request.t() | map() | keyword()
        ) ::
          result()
  def run(configuration, request) do
    with {:ok, canonical_configuration} <- configuration(configuration),
         {:ok, canonical_request} <- Request.prepare(request, canonical_configuration.registry),
         {:ok, state} <- State.new(canonical_request, canonical_configuration.limits) do
      Loop.run(canonical_configuration, state)
    end
  end

  defp configuration(%Configuration{} = configuration) do
    configuration
    |> Map.from_struct()
    |> Configuration.new()
  end

  defp configuration(configuration) do
    Configuration.new(configuration)
  end
end
