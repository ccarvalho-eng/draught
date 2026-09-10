defmodule Draught.Tool.Execution.Outcome do
  @moduledoc """
  Converts executor outcomes into canonical tool results.

  Successful output and normalized failures retain their canonical data;
  validation failures are converted to safe argument errors for the caller.
  """

  alias Draught.Error.Normalized
  alias Draught.Tool.Call
  alias Draught.Tool.Execution.Failure
  alias Draught.Tool.Execution.Feedback
  alias Draught.Tool.Output
  alias Draught.Tool.Result
  alias Draught.Validation.Error

  @doc "Converts a prepared execution outcome into a canonical tool result."
  @spec from_execution(
          {:ok, Output.t()} | {:error, Normalized.t()} | {:error, Error.t()},
          Call.t()
        ) :: Result.t()
  def from_execution({:ok, %Output{} = output}, %Call{} = call) do
    success(call, output)
  end

  def from_execution({:error, %Normalized{} = error}, %Call{} = call) do
    failure(call, error)
  end

  def from_execution({:error, %Error{} = error}, %Call{} = call) do
    error
    |> Failure.invalid_arguments()
    |> then(&failure(call, &1))
  end

  @doc "Builds a canonical successful result for a call."
  @spec success(Call.t(), Output.t()) :: Result.t()
  def success(%Call{} = call, %Output{} = output) do
    {:ok, result} =
      Result.new(
        call_id: call.id,
        name: call.name,
        content: output.content,
        provenance: output.provenance,
        status: :success
      )

    result
  end

  @doc "Builds a canonical error result for a call."
  @spec failure(Call.t(), Normalized.t()) :: Result.t()
  def failure(%Call{} = call, %Normalized{} = error) do
    {:ok, result} =
      Result.new(
        call_id: call.id,
        name: call.name,
        content: Feedback.content(error),
        status: :error,
        error: error
      )

    result
  end
end
