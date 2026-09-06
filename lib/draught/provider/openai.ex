defmodule Draught.Provider.OpenAI do
  @moduledoc """
  OpenAI-compatible implementation of the canonical provider boundary.
  """

  @behaviour Draught.Provider

  alias Draught.Provider.Capabilities
  alias Draught.Provider.OpenAI.Execution.Completion
  alias Draught.Provider.OpenAI.Execution.Stream
  alias Draught.Provider.OpenAI.Protocol
  alias Draught.Provider.OpenAI.Runtime
  alias Draught.Provider.OpenAI.Transport

  @type adapter :: {__MODULE__, Runtime.t()}

  @doc "Builds an adapter using the Req transport or an explicit transport dependency."
  @spec new(map() | keyword(), term()) :: Draught.Validation.result(adapter())
  def new(options \\ %{}, transport \\ {Transport.Req, nil}) do
    with {:ok, runtime} <- Runtime.new(options, transport) do
      {:ok, {__MODULE__, runtime}}
    end
  end

  @impl Draught.Provider
  def capabilities(%Runtime{} = runtime) do
    Capabilities.new(
      chat: true,
      streaming: true,
      tool_calls: true,
      reasoning: runtime.configuration.reasoning_field != :none,
      usage: true
    )
  end

  def capabilities(_runtime) do
    invalid_runtime()
  end

  @impl Draught.Provider
  def complete(request, %Runtime{} = runtime) do
    Completion.run(request, runtime)
  end

  def complete(_request, _runtime) do
    invalid_runtime()
  end

  @impl Draught.Provider
  def stream(request, %Runtime{} = runtime, sink) do
    Stream.run(request, runtime, sink)
  end

  def stream(_request, _runtime, _sink) do
    invalid_runtime()
  end

  defp invalid_runtime do
    Protocol.configuration("invalid_configuration", "OpenAI runtime is invalid")
  end
end
