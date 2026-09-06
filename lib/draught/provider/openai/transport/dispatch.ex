defmodule Draught.Provider.OpenAI.Transport.Dispatch do
  @moduledoc false

  alias Draught.Provider.OpenAI.Runtime

  @doc "Dispatches a complete request to the configured transport."
  @spec complete(Runtime.t(), Draught.Provider.OpenAI.Transport.Request.t()) :: term()
  def complete(%Runtime{} = runtime, request) do
    runtime.transport_module.complete(request, runtime.transport_config)
  end

  @doc "Dispatches a streaming request to the configured transport."
  @spec stream(
          Runtime.t(),
          Draught.Provider.OpenAI.Transport.Request.t(),
          state,
          Draught.Provider.OpenAI.Transport.stream_reducer(state)
        ) :: term()
        when state: term()
  def stream(%Runtime{} = runtime, request, state, reducer) do
    runtime.transport_module.stream(request, runtime.transport_config, state, reducer)
  end
end
