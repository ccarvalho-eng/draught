defmodule Draught.CLI.Task.Provider.Selection do
  @moduledoc """
  Holds a validated provider adapter, its selected model, and advertised capabilities.
  """

  alias Draught.Provider
  alias Draught.Provider.Capabilities
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @enforce_keys [:adapter, :capabilities, :model]
  defstruct [:adapter, :capabilities, :model]

  @type t :: %__MODULE__{
          adapter: Provider.adapter(),
          capabilities: Capabilities.t(),
          model: String.t()
        }

  @doc "Builds a selection and requires chat and tool-call capabilities."
  @spec new(term(), term()) ::
          {:ok, t()} | {:error, Draught.Error.Normalized.t() | Error.t()}
  def new(adapter, model) do
    with {:ok, canonical_model} <- Value.required_string(%{model: model}, :model),
         {:ok, capabilities} <- Provider.capabilities(adapter),
         :ok <- Capabilities.require(capabilities, :chat),
         :ok <- Capabilities.require(capabilities, :tool_calls) do
      {:ok,
       %__MODULE__{
         adapter: adapter,
         capabilities: capabilities,
         model: canonical_model
       }}
    end
  end
end
