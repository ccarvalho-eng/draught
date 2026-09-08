defmodule Draught.Tool.Builtin.ReplaceInFile.Approval do
  @moduledoc """
  Presents exact replacement details before path resolution or mutation.

  The summary retains byte counts only; the separate preview contains escaped
  replacement text and the workspace for the trusted approval interface.
  """

  alias Draught.Error.Normalized
  alias Draught.Tool.Approval.Preview
  alias Draught.Tool.Builtin.Approval
  alias Draught.Tool.Call
  alias Draught.Tool.Execution.Context

  @doc "Requests approval for an already schema-validated replacement call."
  @spec authorize(Call.t(), Context.t()) :: :ok | {:error, Normalized.t()}
  def authorize(call, context) do
    arguments = call.arguments

    preview =
      arguments
      |> Map.put("workspace", context.workspace)
      |> Preview.build()

    Approval.authorize(call, context, :write, arguments["path"], summary(arguments), preview)
  end

  defp summary(arguments) do
    expected_bytes = byte_size(arguments["expected"])
    replacement_bytes = byte_size(arguments["replacement"])
    "path; expected: #{expected_bytes} bytes; replacement: #{replacement_bytes} bytes"
  end
end
