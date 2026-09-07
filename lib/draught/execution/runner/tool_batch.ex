defmodule Draught.Execution.Runner.ToolBatch do
  @moduledoc """
  Derives semantic identity for an ordered batch of tool calls.

  Provider-generated call identifiers are excluded so the runner can detect a
  repeated request even when a provider assigns new identifiers.
  """

  alias Draught.Tool.Call

  @type key :: [{String.t(), map()}]

  @doc "Builds an ordered semantic batch key without provider-generated call IDs."
  @spec key([Call.t()]) :: key()
  def key(calls) do
    Enum.map(calls, &call_key/1)
  end

  defp call_key(%Call{name: name, arguments: arguments}) do
    {name, arguments}
  end
end
