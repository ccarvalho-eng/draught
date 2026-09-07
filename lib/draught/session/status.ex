defmodule Draught.Session.Status do
  @moduledoc """
  Immutable public lifecycle status for one supervised session.
  """

  @enforce_keys [:active_turn_id, :id, :last_outcome, :phase]
  defstruct [:active_turn_id, :id, :last_outcome, :phase]

  @type phase :: :idle | :running
  @type t :: %__MODULE__{
          active_turn_id: pos_integer() | nil,
          id: String.t(),
          last_outcome: Draught.Execution.Runner.result() | nil,
          phase: phase()
        }

  @doc "Builds an idle session status."
  @spec idle(String.t(), Draught.Execution.Runner.result() | nil) :: t()
  def idle(id, last_outcome) do
    %__MODULE__{
      active_turn_id: nil,
      id: id,
      last_outcome: last_outcome,
      phase: :idle
    }
  end

  @doc "Builds a running session status."
  @spec running(String.t(), pos_integer(), Draught.Execution.Runner.result() | nil) :: t()
  def running(id, turn_id, last_outcome) do
    %__MODULE__{
      active_turn_id: turn_id,
      id: id,
      last_outcome: last_outcome,
      phase: :running
    }
  end
end
