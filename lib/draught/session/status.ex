defmodule Draught.Session.Status do
  @moduledoc """
  Immutable public lifecycle status for one supervised session.
  """

  alias Draught.Web.Policy

  @enforce_keys [:active_turn_id, :id, :last_outcome, :phase, :web]
  defstruct [:active_turn_id, :id, :last_outcome, :phase, :web]

  @type phase :: :idle | :running
  @type t :: %__MODULE__{
          active_turn_id: pos_integer() | nil,
          id: String.t(),
          last_outcome: Draught.Execution.Runner.result() | nil,
          phase: phase(),
          web: %{fetch: :disabled | :enabled, search: :disabled | :enabled}
        }

  @doc "Builds an idle session status."
  @spec idle(String.t(), Draught.Execution.Runner.result() | nil, map()) :: t()
  def idle(id, last_outcome, web \\ %{fetch: :disabled, search: :disabled}) do
    %__MODULE__{
      active_turn_id: nil,
      id: id,
      last_outcome: last_outcome,
      phase: :idle,
      web: web
    }
  end

  @doc "Builds a running session status."
  @spec running(String.t(), pos_integer(), Draught.Execution.Runner.result() | nil, map()) :: t()
  def running(id, turn_id, last_outcome, web \\ %{fetch: :disabled, search: :disabled}) do
    %__MODULE__{
      active_turn_id: turn_id,
      id: id,
      last_outcome: last_outcome,
      phase: :running,
      web: web
    }
  end

  @doc "Projects the effective web permissions for a session status."
  @spec web(Policy.t()) :: %{fetch: :disabled | :enabled, search: :disabled | :enabled}
  def web(%Policy{} = policy) do
    Policy.status(policy)
  end
end
