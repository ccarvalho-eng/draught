defmodule Draught.Tool.Specification do
  @moduledoc """
  A provider-neutral declaration of a tool exposed to a model.
  """

  alias Draught.Tool.Name
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.JSON
  alias Draught.Validation.Value

  @enforce_keys [:name, :description, :input_schema]
  defstruct [:name, :description, :input_schema]

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t(),
          input_schema: %{String.t() => JSON.value()}
        }

  @doc "Builds a validated tool specification from external attributes."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes) do
    with {:ok, normalized} <-
           Attributes.normalize(attributes, [:name, :description, :input_schema]),
         {:ok, raw_name} <- Attributes.fetch_required(normalized, :name),
         {:ok, name} <- Name.validate(raw_name),
         {:ok, description} <- Value.required_string(normalized, :description),
         {:ok, input_schema} <- input_schema(normalized) do
      {:ok, %__MODULE__{name: name, description: description, input_schema: input_schema}}
    end
  end

  defp input_schema(attributes) do
    with {:ok, schema} <- Attributes.fetch_required(attributes, :input_schema) do
      case JSON.validate_object(schema, [:input_schema]) do
        :ok -> {:ok, schema}
        {:error, _error} = result -> result
      end
    end
  end
end
