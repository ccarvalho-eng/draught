defmodule Draught.Provider.Ollama.Execution do
  @moduledoc """
  Executes Ollama requests behind bounded malformed-tool-call recovery.

  Stream events remain buffered until the response is known to be canonical so
  leaked model markup cannot reach the terminal or durable session history.
  """

  alias Draught.Provider.Ollama.Execution.Recovery
  alias Draught.Provider.Ollama.Stream.Replay
  alias Draught.Provider.OpenAI
  alias Draught.Provider.OpenAI.Runtime
  alias Draught.Provider.Request

  @doc "Completes one request and retries one malformed textual tool call."
  @spec complete(Request.t(), Runtime.t()) ::
          Draught.Provider.provider_result(Draught.Provider.Response.t())
  def complete(%Request{} = request, %Runtime{} = runtime) do
    Recovery.run(request, fn -> OpenAI.complete(request, runtime) end)
  end

  @doc "Streams one validated response after bounded malformed-call recovery."
  @spec stream(Request.t(), Runtime.t(), Draught.Provider.adapter_sink()) ::
          Draught.Provider.provider_result(Draught.Provider.Response.t())
  def stream(%Request{tools: []} = request, %Runtime{} = runtime, sink)
      when is_function(sink, 1) do
    OpenAI.stream(request, runtime, sink)
  end

  def stream(%Request{tools: [_tool | _rest]} = request, %Runtime{} = runtime, sink)
      when is_function(sink, 1) do
    with {:ok, response} <-
           Recovery.run(request, fn -> OpenAI.stream(request, runtime, &discard/1) end),
         :ok <- Replay.emit(response, sink) do
      {:ok, response}
    end
  end

  defp discard(_event) do
    :ok
  end
end
