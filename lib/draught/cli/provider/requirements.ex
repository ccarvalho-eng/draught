defmodule Draught.CLI.Provider.Requirements do
  @moduledoc """
  Validates the provider capabilities required by CLI agent execution.
  """

  @agent [:chat, :streaming, :tool_calls]

  @doc "Returns the capabilities required by the current CLI execution path."
  @spec agent() :: [Draught.Provider.Capabilities.feature()]
  def agent do
    @agent
  end
end
