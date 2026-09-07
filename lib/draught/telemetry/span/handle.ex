defmodule Draught.Telemetry.Span.Handle do
  @moduledoc false

  @enforce_keys [:guard, :token]
  defstruct [:guard, :token]

  @type t :: %__MODULE__{guard: pid(), token: reference()}

  @doc "Builds ownership data for one guarded telemetry span."
  @spec new(pid(), reference()) :: t()
  def new(guard, token) do
    %__MODULE__{guard: guard, token: token}
  end
end
