defmodule Draught.CLI.Interactive.Session.Doctor do
  @moduledoc """
  Runs diagnostics requested from an open interactive session.

  The boundary keeps diagnostic command wiring out of the session controller
  while preserving the diagnostic command's exit status.
  """

  alias Draught.CLI.Command.Invocation
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Doctor.Command

  @doc "Runs the diagnostic command for an invocation prepared by the controller."
  @spec run(Invocation.t(), Dependencies.t()) :: non_neg_integer()
  def run(invocation, dependencies) do
    Command.run(invocation, dependencies)
  end
end
