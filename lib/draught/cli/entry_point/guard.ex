defmodule Draught.CLI.EntryPoint.Guard do
  @moduledoc false

  @type result(value) :: {:ok, value} | :error

  @doc "Runs the executable boundary and normalizes expected runtime exception classes."
  @spec run(input, (input -> value)) :: result(value) when input: term(), value: term()
  def run(input, operation) when is_function(operation, 1) do
    {:ok, operation.(input)}
  rescue
    _error in [
      ArgumentError,
      CaseClauseError,
      ErlangError,
      FunctionClauseError,
      KeyError,
      MatchError,
      RuntimeError
    ] ->
      :error
  end
end
