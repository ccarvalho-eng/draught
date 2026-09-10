defmodule Draught.Tool.Execution.Feedback do
  @moduledoc """
  Builds fixed model-facing feedback for failed tool operations.
  """

  alias Draught.Error.Normalized

  @doc "Builds bounded feedback that makes a failed tool outcome explicit."
  @spec content(Normalized.t()) :: String.t()
  def content(%Normalized{} = error) do
    "Tool execution failed (#{error.code}).\n" <>
      "The requested operation was not performed. Do not report it as completed."
  end
end
