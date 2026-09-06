defmodule Draught.Tool.Definition do
  @moduledoc """
  Executable tool metadata kept separate from provider serialization.
  """

  alias Draught.Tool.Executor.Adapter
  alias Draught.Tool.Risk
  alias Draught.Tool.Specification
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error

  @enforce_keys [:specification, :risk, :executor]
  defstruct [:specification, :risk, :executor]

  @type t :: %__MODULE__{
          specification: Specification.t(),
          risk: Risk.t(),
          executor: {module(), term()}
        }

  @doc "Builds an executable definition from metadata, risk, and an executor."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes) do
    with {:ok, normalized} <-
           Attributes.normalize(
             attributes,
             [:name, :description, :input_schema, :risk, :executor]
           ),
         {:ok, specification} <- specification(normalized),
         {:ok, risk} <- risk(normalized),
         {:ok, executor} <- executor(normalized) do
      {:ok, %__MODULE__{specification: specification, risk: risk, executor: executor}}
    end
  end

  defp specification(attributes) do
    attributes
    |> Map.take([:name, :description, :input_schema])
    |> Specification.new()
  end

  defp risk(attributes) do
    with {:ok, risk} <- Attributes.fetch_required(attributes, :risk) do
      Risk.validate(risk)
    end
  end

  defp executor(attributes) do
    with {:ok, executor} <- Attributes.fetch_required(attributes, :executor) do
      Adapter.validate(executor)
    end
  end
end
