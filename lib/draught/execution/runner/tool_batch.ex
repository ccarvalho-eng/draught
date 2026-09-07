defmodule Draught.Execution.Runner.ToolBatch do
  @moduledoc false

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
