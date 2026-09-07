defmodule Draught.Execution.Runner.ProviderExecution.Stream.EventRelay do
  @moduledoc """
  Selects canonical nonterminal provider events for the bounded stream relay.
  """

  alias Draught.Event.Provider.Completed
  alias Draught.Event.Provider.Delta
  alias Draught.Event.Provider.Failed
  alias Draught.Event.Provider.ToolCall

  @doc "Relays visible nonterminal provider events and consumes facade terminal events."
  @spec emit(Draught.Event.t(), (Draught.Event.nonterminal() -> term())) :: term()
  def emit(%Delta{} = event, relay) do
    relay.(event)
  end

  def emit(%ToolCall{} = event, relay) do
    relay.(event)
  end

  def emit(%Completed{}, _relay) do
    :ok
  end

  def emit(%Failed{}, _relay) do
    :ok
  end
end
