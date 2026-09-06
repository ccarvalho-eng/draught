defmodule Draught.Event.Provider.Failed do
  @moduledoc """
  The terminal failure event of a provider stream.
  """

  alias Draught.Error.Normalized
  alias Draught.Validation
  alias Draught.Validation.Attributes

  @enforce_keys [:error]
  defstruct [:error]

  @type t :: %__MODULE__{error: Normalized.t()}

  @doc "Builds a validated provider failure event."
  @spec new(map() | keyword()) :: Validation.result(t())
  def new(attributes) do
    with {:ok, normalized} <- Attributes.normalize(attributes, [:error]),
         {:ok, raw_error} <- Attributes.fetch_required(normalized, :error),
         {:ok, error} <- error(raw_error) do
      {:ok, %__MODULE__{error: error}}
    end
  end

  defp error(%Normalized{} = error) do
    error
    |> Map.from_struct()
    |> Normalized.new()
  end

  defp error(attributes) do
    Normalized.new(attributes)
  end
end
