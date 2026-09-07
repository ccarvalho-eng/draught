defmodule Draught.Tool.Approval.Decision do
  @moduledoc """
  Canonical approval outcome returned by a policy.
  """

  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @outcomes [:allow, :ask, :deny]
  @maximum_reason_bytes 512
  @control_bytes ~r/[\x00-\x1F\x7F]/

  @enforce_keys [:outcome]
  defstruct [:outcome, :reason]

  @type outcome :: :allow | :ask | :deny
  @type t :: %__MODULE__{outcome: outcome(), reason: String.t() | nil}

  @doc "Builds a bounded approval decision."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes) do
    with {:ok, normalized} <- Attributes.normalize(attributes, [:outcome, :reason]),
         {:ok, outcome} <- outcome(normalized),
         {:ok, reason} <- reason(normalized) do
      {:ok, %__MODULE__{outcome: outcome, reason: reason}}
    end
  end

  defp outcome(attributes) do
    with {:ok, outcome} <- Attributes.fetch_required(attributes, :outcome) do
      Value.enum(outcome, @outcomes, [:outcome])
    end
  end

  defp reason(attributes) do
    case Map.get(attributes, :reason) do
      nil ->
        {:ok, nil}

      reason ->
        with {:ok, value} <- Value.string(reason, [:reason]),
             true <- byte_size(value) <= @maximum_reason_bytes,
             false <- Regex.match?(@control_bytes, value) do
          {:ok, value}
        else
          true -> Error.single([:reason], :invalid_value, "must not contain control characters")
          false -> Error.single([:reason], :too_large, "exceeds the maximum byte size")
          {:error, %Error{}} = result -> result
        end
    end
  end
end
