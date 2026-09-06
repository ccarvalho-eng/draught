defmodule Draught.Provider.OpenAI.Execution.Completion do
  @moduledoc """
  Executes bounded non-streaming OpenAI-compatible requests.
  """

  alias Draught.Provider.OpenAI.Execution.Completion.Result
  alias Draught.Provider.OpenAI.Execution.Retry
  alias Draught.Provider.OpenAI.Runtime
  alias Draught.Provider.OpenAI.Transport.Dispatch
  alias Draught.Provider.OpenAI.Transport.Request.Builder

  @doc "Executes and decodes one canonical provider request."
  @spec run(Draught.Provider.Request.t(), Runtime.t()) ::
          {:ok, Draught.Provider.Response.t()} | {:error, Draught.Error.Normalized.t()}
  def run(request, %Runtime{} = runtime) do
    with {:ok, transport_request} <- Builder.build(request, runtime.configuration, :complete) do
      Retry.run(runtime.configuration.retry, fn -> attempt(runtime, transport_request) end)
    end
  end

  defp attempt(runtime, request) do
    runtime
    |> Dispatch.complete(request)
    |> Result.normalize()
  end
end
