defmodule Draught.CLI.Task.Command.Result do
  @moduledoc """
  Emits one projected terminal task outcome and returns its exit status.
  """

  alias Draught.CLI.Command.ExitStatus
  alias Draught.CLI.Task.Stream
  alias Draught.Error.Normalized

  @doc "Projects a task result and returns its stable operating-system status."
  @spec emit(Draught.CLI.Task.result(), Stream.t()) :: non_neg_integer()
  def emit(result, %Stream{} = stream) do
    case Stream.finish(stream, result) do
      {:ok, _finished} ->
        category = exit_category(result)
        ExitStatus.value(category)

      {:error, _reason, _failed} ->
        ExitStatus.value(:internal)
    end
  end

  defp exit_category({:ok, _response}) do
    :success
  end

  defp exit_category({:error, :provider, _error}) do
    :provider
  end

  defp exit_category({:error, :session, _error}) do
    :session
  end

  defp exit_category({:error, :execution, %Normalized{kind: :cancellation}}) do
    :interrupted
  end

  defp exit_category({:error, :execution, _error}) do
    :execution
  end
end
