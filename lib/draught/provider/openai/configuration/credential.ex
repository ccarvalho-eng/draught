defmodule Draught.Provider.OpenAI.Configuration.Credential do
  @moduledoc """
  A provider credential whose inspection never reveals its value.
  """

  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @enforce_keys [:value]
  defstruct [:value]

  @type t :: %__MODULE__{value: String.t()}

  @doc "Builds a credential from a non-empty UTF-8 string."
  @spec new(term()) :: Error.result(t())
  def new(value) do
    case Value.string(value, [:credential]) do
      {:ok, validated} -> {:ok, %__MODULE__{value: validated}}
      {:error, _error} = result -> result
    end
  end

  @doc "Returns the credential for the provider transport boundary."
  @spec value(t()) :: String.t()
  def value(%__MODULE__{value: value}) do
    value
  end
end

defimpl Inspect, for: Draught.Provider.OpenAI.Configuration.Credential do
  import Inspect.Algebra

  @spec inspect(
          Draught.Provider.OpenAI.Configuration.Credential.t(),
          Inspect.Opts.t()
        ) :: Inspect.Algebra.t()
  def inspect(_credential, _options) do
    concat(["#Draught.Provider.OpenAI.Configuration.Credential<redacted>"])
  end
end
