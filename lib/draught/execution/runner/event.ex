defmodule Draught.Execution.Runner.Event do
  @moduledoc """
  Event values emitted synchronously by the agent runner.
  """

  alias Draught.Error.Normalized
  alias Draught.Provider.Response
  alias Draught.Tool.Result

  @type provider_result :: {:ok, Response.t()} | {:error, Normalized.t()}
  @type terminal_result :: provider_result()
  @type t ::
          {:provider_result, pos_integer(), provider_result()}
          | {:tool_result, pos_integer(), Result.t()}
          | {:terminal, terminal_result()}

  @type sink :: (t() -> :ok)
end
