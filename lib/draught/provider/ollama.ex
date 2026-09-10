defmodule Draught.Provider.Ollama do
  @moduledoc """
  Ollama preset backed by the OpenAI-compatible provider implementation.
  """

  @behaviour Draught.Provider

  alias Draught.Provider.Ollama.Builder
  alias Draught.Provider.Ollama.Execution
  alias Draught.Provider.Ollama.Protocol
  alias Draught.Provider.Ollama.Runtime

  @type adapter :: {__MODULE__, Runtime.t()}

  @doc "Builds an Ollama adapter after model selection and capability validation."
  @spec new(map() | keyword(), map() | keyword()) ::
          {:ok, adapter()} | {:error, Draught.Error.Normalized.t() | Draught.Validation.Error.t()}
  def new(options \\ %{}, dependencies \\ %{}) do
    Builder.new(options, dependencies)
  end

  @doc "Returns the exact model selected for an Ollama adapter."
  @spec selected_model(term()) :: {:ok, String.t()} | {:error, Draught.Error.Normalized.t()}
  def selected_model({__MODULE__, %Runtime{model: model}}) do
    {:ok, model}
  end

  def selected_model(_adapter) do
    Protocol.invalid_runtime()
  end

  @impl Draught.Provider
  def capabilities(%Runtime{capabilities: capabilities}) do
    {:ok, capabilities}
  end

  def capabilities(_runtime) do
    Protocol.invalid_runtime()
  end

  @impl Draught.Provider
  def complete(request, %Runtime{openai: openai}) do
    Execution.complete(request, openai)
  end

  def complete(_request, _runtime) do
    Protocol.invalid_runtime()
  end

  @impl Draught.Provider
  def stream(request, %Runtime{openai: openai}, sink) do
    Execution.stream(request, openai, sink)
  end

  def stream(_request, _runtime, _sink) do
    Protocol.invalid_runtime()
  end
end
