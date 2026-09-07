defmodule Draught.CLI.Doctor do
  @moduledoc """
  Runs bounded, read-only checks for a resolved CLI configuration.
  """

  alias Draught.CLI.Configuration
  alias Draught.CLI.Doctor.Provider
  alias Draught.CLI.Doctor.Report
  alias Draught.CLI.Doctor.Workspace

  @doc "Checks the workspace and selected provider without model inference or mutation."
  @spec run(Configuration.t(), String.t(), {module(), term()}, module()) :: Report.t()
  def run(
        %Configuration{} = configuration,
        workspace,
        {system, system_configuration},
        discovery_http
      ) do
    checks = [
      Workspace.check(workspace, system, system_configuration),
      Provider.check(configuration, discovery_http)
    ]

    Report.new(checks, configuration)
  end
end
