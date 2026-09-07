defmodule Draught.Execution.Runner.Sink do
  @moduledoc """
  Delivers synchronous runner events through an injected sink function.

  A sink must return `:ok`; any other value becomes a normalized configuration
  failure so event delivery cannot silently diverge from execution.
  """

  alias Draught.Execution.Runner.Failure.Runtime

  @doc "Emits one runner event through the injected synchronous sink."
  @spec emit((term() -> term()), term()) :: :ok | {:error, Draught.Error.Normalized.t()}
  def emit(sink, event) do
    case sink.(event) do
      :ok -> :ok
      _result -> {:error, Runtime.invalid_sink_result()}
    end
  end
end
