defmodule Draught.Conversation.Document.Collection do
  @moduledoc false

  alias Draught.Validation.Error

  @doc "Restores a successfully accumulated collection to input order."
  @spec finish(Error.result([term()]) | {:ok, [term()], term()}) :: Error.result([term()])
  def finish({:ok, values}) do
    {:ok, Enum.reverse(values)}
  end

  def finish({:ok, values, _context}) do
    {:ok, Enum.reverse(values)}
  end

  def finish({:error, %Error{}} = result) do
    result
  end

  @doc "Prefixes each validation violation with its collection path."
  @spec prefix_error(Error.t(), [term()]) :: Error.t()
  def prefix_error(%Error{} = error, path) do
    violations =
      Enum.map(error.violations, fn violation ->
        %{violation | path: path ++ violation.path}
      end)

    Error.new(violations)
  end
end
