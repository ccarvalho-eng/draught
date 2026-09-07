defmodule Draught.CLI.Doctor.Command do
  @moduledoc false

  alias Draught.CLI.Command
  alias Draught.CLI.Configuration.Error
  alias Draught.CLI.Configuration.Loader
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Doctor
  alias Draught.CLI.Output
  alias Draught.CLI.Writer

  @doc "Runs a doctor invocation and emits its report through the configured system boundary."
  @spec run(Command.Invocation.t(), Dependencies.t()) :: non_neg_integer()
  def run(%Command.Invocation{} = invocation, %Dependencies{} = dependencies) do
    case Loader.load(invocation, dependencies.system) do
      {:ok, configuration, workspace} ->
        configuration
        |> Doctor.run(workspace, dependencies.system, dependencies.discovery_http)
        |> report(invocation.output, dependencies)

      {:error, %Error{} = error} ->
        error
        |> Output.configuration_error(invocation.output)
        |> Writer.emit(:stderr, :usage, dependencies)
    end
  end

  defp report(%Doctor.Report{status: :ok} = report, output, dependencies) do
    report
    |> Output.doctor(output)
    |> Writer.emit(:stdout, :success, dependencies)
  end

  defp report(%Doctor.Report{status: :error} = report, output, dependencies) do
    report
    |> Output.doctor(output)
    |> Writer.emit(:stdout, :provider, dependencies)
  end
end
