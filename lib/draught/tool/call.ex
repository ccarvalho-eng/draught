defmodule Draught.Tool.Call do
  @moduledoc """
  A provider-neutral request to invoke one named tool.
  """

  alias Draught.Tool.Name
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.JSON
  alias Draught.Validation.Value

  @enforce_keys [:id, :name, :arguments]
  defstruct [:id, :name, :arguments]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          arguments: %{String.t() => JSON.value()}
        }

  @doc "Builds a validated tool call from external attributes."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes) do
    with {:ok, normalized} <- Attributes.normalize(attributes, [:id, :name, :arguments]),
         {:ok, id} <- Value.required_string(normalized, :id),
         {:ok, raw_name} <- Attributes.fetch_required(normalized, :name),
         {:ok, name} <- Name.validate(raw_name),
         {:ok, arguments} <- arguments(normalized) do
      {:ok, %__MODULE__{id: id, name: name, arguments: arguments}}
    end
  end

  defp arguments(attributes) do
    arguments = Map.get(attributes, :arguments, %{})

    case JSON.validate_object(arguments, [:arguments]) do
      :ok -> {:ok, arguments}
      {:error, _error} = result -> result
    end
  end
end
