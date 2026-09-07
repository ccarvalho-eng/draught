defmodule Draught.CLI.Provider.Requirements do
  @moduledoc false

  @agent [:chat, :tool_calls]

  @doc "Returns the capabilities required by the current CLI execution path."
  @spec agent() :: [Draught.Provider.Capabilities.feature()]
  def agent do
    @agent
  end
end
