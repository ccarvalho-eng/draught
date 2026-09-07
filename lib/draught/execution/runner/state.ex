defmodule Draught.Execution.Runner.State do
  @moduledoc """
  Immutable state for one bounded provider-tool run.
  """

  alias Draught.Error.Normalized
  alias Draught.Execution.Runner.Limits
  alias Draught.Provider.Request
  alias Draught.Provider.Response
  alias Draught.Tool.Call
  alias Draught.Validation.Error

  @statuses [:completed, :failed, :ready, :waiting_provider, :waiting_tools]

  @enforce_keys [
    :iteration,
    :limits,
    :messages,
    :outcome,
    :pending_calls,
    :request,
    :seen_batches,
    :status
  ]
  defstruct [
    :iteration,
    :limits,
    :messages,
    :outcome,
    :pending_calls,
    :request,
    :seen_batches,
    :status
  ]

  @type status :: :completed | :failed | :ready | :waiting_provider | :waiting_tools
  @type outcome :: Response.t() | Normalized.t() | nil
  @type t :: %__MODULE__{
          iteration: non_neg_integer(),
          limits: Limits.t(),
          messages: [Draught.Conversation.Message.t()],
          outcome: outcome(),
          pending_calls: [Call.t()],
          request: Request.t(),
          seen_batches: MapSet.t([{String.t(), map()}]),
          status: status()
        }

  @doc "Builds initial runner state from a request and limits."
  @spec new(Request.t(), Limits.t()) :: Error.result(t())
  def new(%Request{} = request, %Limits{} = limits) do
    with {:ok, canonical_request} <- canonical_request(request),
         {:ok, canonical_limits} <- canonical_limits(limits) do
      {:ok,
       %__MODULE__{
         iteration: 0,
         limits: canonical_limits,
         messages: canonical_request.messages,
         outcome: nil,
         pending_calls: [],
         request: canonical_request,
         seen_batches: MapSet.new(),
         status: :ready
       }}
    end
  end

  @doc "Returns pending calls in provider declaration order."
  @spec pending_calls(t()) :: [Call.t()]
  def pending_calls(%__MODULE__{pending_calls: calls}) do
    calls
  end

  @doc "Returns the current terminal outcome or `:running`."
  @spec outcome(t()) :: :running | {:ok, Response.t()} | {:error, Normalized.t()}
  def outcome(%__MODULE__{status: :completed, outcome: %Response{} = response}) do
    {:ok, response}
  end

  def outcome(%__MODULE__{status: :failed, outcome: %Normalized{} = error}) do
    {:error, error}
  end

  def outcome(%__MODULE__{status: status}) when status in @statuses do
    :running
  end

  defp canonical_request(request) do
    request
    |> Map.from_struct()
    |> Request.new()
  end

  defp canonical_limits(limits) do
    limits
    |> Map.from_struct()
    |> Limits.new()
  end
end
