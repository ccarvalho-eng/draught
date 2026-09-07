defmodule Draught.Session.Runtime.State do
  @moduledoc false

  alias Draught.Session.Runtime.ActiveTurn
  alias Draught.Session.Settings
  alias Draught.Session.Status

  @enforce_keys [:active, :last_outcome, :next_turn_id, :settings]
  defstruct [:active, :last_outcome, :next_turn_id, :settings]

  @type t :: %__MODULE__{
          active: ActiveTurn.t() | nil,
          last_outcome: Draught.Execution.Runner.result() | nil,
          next_turn_id: pos_integer(),
          settings: Settings.t()
        }

  @doc "Builds the initial idle runtime state."
  @spec new(Settings.t()) :: t()
  def new(%Settings{} = settings) do
    %__MODULE__{active: nil, last_outcome: nil, next_turn_id: 1, settings: settings}
  end

  @doc "Applies the pure transition from idle to an active turn."
  @spec start_turn(t(), ActiveTurn.t()) :: t()
  def start_turn(%__MODULE__{active: nil} = state, %ActiveTurn{} = active) do
    %{state | active: active, next_turn_id: active.id + 1}
  end

  @doc "Applies the pure transition from an active turn to idle."
  @spec finish_turn(t(), Draught.Execution.Runner.result()) :: t()
  def finish_turn(%__MODULE__{} = state, outcome) do
    %{state | active: nil, last_outcome: outcome}
  end

  @doc "Projects internal runtime state into its public status value."
  @spec status(t()) :: Status.t()
  def status(%__MODULE__{active: nil} = state) do
    Status.idle(state.settings.id, state.last_outcome)
  end

  def status(%__MODULE__{active: %ActiveTurn{} = active} = state) do
    Status.running(state.settings.id, active.id, state.last_outcome)
  end
end
