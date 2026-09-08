defmodule Draught.CLI.EntryPoint.Failure do
  @moduledoc """
  Defines process-level startup failures shared by executable entry points.
  """

  alias Draught.CLI.Command.ExitStatus

  @type t :: {String.t(), non_neg_integer()}

  @doc "Returns the sanitized message and stable status for a startup failure."
  @spec startup() :: t()
  def startup do
    {"Draught could not start.\n", ExitStatus.value(:internal)}
  end
end
