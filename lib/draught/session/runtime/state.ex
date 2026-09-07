defmodule Draught.Session.Runtime.State do
  @moduledoc """
  Holds immutable runtime state for a supervised session and records its durable transitions.
  """

  alias Draught.Session.Failure
  alias Draught.Session.Journal
  alias Draught.Session.Journal.Event
  alias Draught.Session.Journal.Replay
  alias Draught.Session.Runtime.ActiveTurn
  alias Draught.Session.Settings
  alias Draught.Session.Status

  @enforce_keys [:active, :journal, :last_outcome, :next_turn_id, :settings]
  defstruct [:active, :journal, :last_outcome, :next_turn_id, :settings]

  @type t :: %__MODULE__{
          active: ActiveTurn.t() | nil,
          journal: Journal.handle() | nil,
          last_outcome: Draught.Execution.Runner.result() | nil,
          next_turn_id: pos_integer(),
          settings: Settings.t()
        }

  @doc "Builds the initial idle runtime state."
  @spec new(Settings.t()) ::
          {:ok, t()} | {:error, Draught.Error.Normalized.t() | Draught.Validation.Error.t()}
  def new(%Settings{} = settings) do
    with {:ok, journal, replay} <- open_journal(settings),
         {:ok, recovered_journal, recovered_replay} <- recover_interrupted(journal, replay) do
      {:ok,
       %__MODULE__{
         active: nil,
         journal: recovered_journal,
         last_outcome: last_outcome(recovered_replay),
         next_turn_id: recovered_replay.last_turn_id + 1,
         settings: settings
       }}
    end
  end

  @doc "Appends one journal event and advances the writer handle."
  @spec record(t(), Event.t()) ::
          {:ok, t()} | {:error, Draught.Error.Normalized.t() | Draught.Validation.Error.t()}
  def record(%__MODULE__{journal: nil} = state, _event) do
    {:ok, state}
  end

  def record(%__MODULE__{journal: journal} = state, event) do
    with {:ok, updated} <- Journal.append(journal, event) do
      {:ok, %{state | journal: updated}}
    end
  end

  @doc "Writes a disposable checkpoint for the current journal."
  @spec checkpoint(t()) ::
          {:ok, t()} | {:error, Draught.Error.Normalized.t() | Draught.Validation.Error.t()}
  def checkpoint(%__MODULE__{journal: nil} = state) do
    {:ok, state}
  end

  def checkpoint(%__MODULE__{journal: journal} = state) do
    with {:ok, updated} <- Journal.checkpoint(journal) do
      {:ok, %{state | journal: updated}}
    end
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
    Status.idle(state.settings.id, state.last_outcome, web_status(state))
  end

  def status(%__MODULE__{active: %ActiveTurn{} = active} = state) do
    Status.running(state.settings.id, active.id, state.last_outcome, web_status(state))
  end

  defp web_status(state) do
    Status.web(state.settings.runner.tool_context.web.policy)
  end

  defp open_journal(%Settings{journal: nil, id: id}) do
    {:ok, nil, Replay.empty(id)}
  end

  defp open_journal(%Settings{journal: adapter}) do
    Journal.open(adapter)
  end

  defp last_outcome(%Replay{terminal: {:completed, _turn_id, outcome}}) do
    outcome
  end

  defp last_outcome(%Replay{}) do
    nil
  end

  defp recover_interrupted(journal, %Replay{terminal: {:interrupted, turn_id}} = replay) do
    outcome = {:error, Failure.interrupted()}
    event = {:turn_terminal, turn_id, outcome}

    with {:ok, updated} <- Journal.append(journal, event) do
      {:ok, updated, %{replay | terminal: {:completed, turn_id, outcome}}}
    end
  end

  defp recover_interrupted(journal, %Replay{} = replay) do
    {:ok, journal, replay}
  end
end
