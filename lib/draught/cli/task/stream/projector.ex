defmodule Draught.CLI.Task.Stream.Projector do
  @moduledoc """
  Reduces runner events and terminal outcomes into a safe CLI event sequence.

  Projection is pure. Reasoning, call identifiers, tool arguments, tool output,
  provenance, and provider-result duplicates never enter the public sequence.
  """

  alias Draught.CLI.Task.Stream.Projector.ProviderEvent
  alias Draught.CLI.Task.Stream.Projector.State
  alias Draught.CLI.Task.Stream.Projector.Terminal

  @type state :: State.t()

  @doc "Initializes projection and text presentation for one bounded output stream."
  @spec new(:text | :jsonl, pos_integer(), keyword()) :: state()
  def new(format, maximum_bytes, options \\ []) do
    State.new(format, maximum_bytes, options)
  end

  @type projection ::
          ProviderEvent.projection() | Terminal.projection()

  @doc "Projects one ordered runner event into zero or one safe CLI events."
  @spec project(State.t(), Draught.Execution.Runner.Event.t()) :: projection()
  def project(%State{} = state, event) do
    ProviderEvent.project(state, event)
  end

  @doc "Projects the task outcome as the single terminal CLI event."
  @spec finish(State.t(), Draught.CLI.Task.result()) :: projection()
  def finish(%State{} = state, result) do
    Terminal.project(state, result)
  end
end
