defmodule Draught.Event.Provider.Completed do
  @moduledoc """
  The terminal successful event of a provider stream.
  """

  alias Draught.Provider.Response
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error

  @enforce_keys [:response]
  defstruct [:response]

  @type t :: %__MODULE__{response: Response.t()}

  @doc "Builds a validated provider completion event."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes) do
    with {:ok, normalized} <- Attributes.normalize(attributes, [:response]),
         {:ok, raw_response} <- Attributes.fetch_required(normalized, :response),
         {:ok, response} <- response(raw_response) do
      {:ok, %__MODULE__{response: response}}
    end
  end

  defp response(%Response{} = response) do
    response
    |> Map.from_struct()
    |> Response.new()
  end

  defp response(attributes) do
    Response.new(attributes)
  end
end
