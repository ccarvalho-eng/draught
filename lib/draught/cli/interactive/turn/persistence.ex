defmodule Draught.CLI.Interactive.Turn.Persistence do
  @moduledoc """
  Detects whether an interactive turn established durable named-session state.

  A runner failure can occur after the binding and journal are published. The
  shell must resume that durable state instead of attempting to create the same
  identifier again.
  """

  alias Draught.CLI.Dependencies
  alias Draught.CLI.Interactive.Session.Lookup
  alias Draught.CLI.Interactive.State

  @doc "Returns whether the current session has a readable active catalog entry."
  @spec established?(State.t(), Dependencies.t()) :: boolean()
  def established?(%State{persisted?: true}, %Dependencies{}) do
    true
  end

  def established?(%State{} = state, %Dependencies{} = dependencies) do
    state.session_id
    |> Lookup.fetch(state, dependencies)
    |> established_result?()
  end

  defp established_result?({:ok, _entry}) do
    true
  end

  defp established_result?({:error, _reason}) do
    false
  end
end
