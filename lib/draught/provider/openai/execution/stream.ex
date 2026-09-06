defmodule Draught.Provider.OpenAI.Execution.Stream do
  @moduledoc """
  Executes bounded OpenAI-compatible streams with provider-owned retry policy.
  """

  alias Draught.Provider.OpenAI.Execution.Retry
  alias Draught.Provider.OpenAI.Execution.Stream.Attempt
  alias Draught.Provider.OpenAI.Runtime
  alias Draught.Provider.OpenAI.Transport.Request.Builder

  @doc "Executes one canonical streaming provider request."
  @spec run(Draught.Provider.Request.t(), Runtime.t(), Draught.Provider.adapter_sink()) ::
          {:ok, Draught.Provider.Response.t()} | {:error, Draught.Error.Normalized.t()}
  def run(request, %Runtime{} = runtime, sink) do
    with {:ok, transport_request} <- Builder.build(request, runtime.configuration, :stream) do
      Retry.run(runtime.configuration.retry, fn ->
        Attempt.run(runtime, transport_request, sink)
      end)
    end
  end
end
