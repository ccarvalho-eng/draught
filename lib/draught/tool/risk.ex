defmodule Draught.Tool.Risk do
  @moduledoc """
  Closed risk classes used by tool policy.
  """

  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @classes [:read, :write, :execute, :network]
  @type t :: :read | :write | :execute | :network

  @doc "Validates a tool risk class."
  @spec validate(term(), [term()]) :: Error.result(t())
  def validate(value, path \\ [:risk]) do
    Value.enum(value, @classes, path)
  end

  @doc "Lists the closed risk-class set."
  @spec classes() :: [t()]
  def classes do
    @classes
  end
end
