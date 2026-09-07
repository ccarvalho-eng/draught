defmodule Draught.CLI.Task.Preparation.Limits do
  @moduledoc false

  alias Draught.Execution.Runner.Limits
  alias Draught.Validation.Error

  @doc "Reconstructs explicit limits or builds bounded defaults."
  @spec new(map()) :: Error.result(Limits.t())
  def new(%{limits: %Limits{} = limits}) do
    limits
    |> Map.from_struct()
    |> Limits.new()
  end

  def new(attributes) do
    attributes
    |> Map.get(:limits, [])
    |> Limits.new()
  end
end
