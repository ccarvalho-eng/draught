defmodule Draught.Event.Provider.ToolCall do
  @moduledoc """
  A complete canonical tool call emitted by a provider stream.
  """

  alias Draught.Tool.Call
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error

  @enforce_keys [:call]
  defstruct [:call]

  @type t :: %__MODULE__{call: Call.t()}

  @doc "Builds a validated streamed tool-call event."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes) do
    with {:ok, normalized} <- Attributes.normalize(attributes, [:call]),
         {:ok, raw_call} <- Attributes.fetch_required(normalized, :call),
         {:ok, call} <- call(raw_call) do
      {:ok, %__MODULE__{call: call}}
    end
  end

  defp call(%Call{} = call) do
    call
    |> Map.from_struct()
    |> Call.new()
  end

  defp call(attributes) do
    Call.new(attributes)
  end
end
