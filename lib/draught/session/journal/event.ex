defmodule Draught.Session.Journal.Event do
  @moduledoc """
  Defines the canonical events accepted by session journal adapters.
  """

  @type t ::
          {:turn_started, pos_integer(), String.t(), Draught.Provider.Request.t()}
          | {:provider_result, pos_integer(), pos_integer(), Draught.Execution.Runner.result()}
          | {:tool_result, pos_integer(), pos_integer(), Draught.Tool.Result.t()}
          | {:turn_terminal, pos_integer(), Draught.Execution.Runner.result()}
end
