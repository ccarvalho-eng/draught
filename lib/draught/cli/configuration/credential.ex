defmodule Draught.CLI.Configuration.Credential do
  @moduledoc """
  Holds an environment credential bound to one selected trusted profile.
  """

  alias Draught.CLI.Configuration.Error

  @enforce_keys [:profile, :value]
  defstruct [:profile, :value]

  @type t :: %__MODULE__{profile: String.t(), value: String.t()}

  @doc "Builds a credential without retaining malformed input in errors."
  @spec new(String.t(), term()) :: Error.result(t())
  def new(profile, value) when is_binary(value) do
    valid = byte_size(value) > 0 and byte_size(value) <= 16_384 and String.valid?(value)
    build(valid, profile, value)
  end

  def new(_profile, _value) do
    Error.new(:environment, [:credential], :invalid_value, "must be a non-empty UTF-8 value")
  end

  @doc "Returns the secret only at the provider construction boundary."
  @spec value(t()) :: String.t()
  def value(%__MODULE__{value: value}) do
    value
  end

  defp build(true, profile, value) do
    {:ok, %__MODULE__{profile: profile, value: value}}
  end

  defp build(false, _profile, _value) do
    Error.new(:environment, [:credential], :invalid_value, "must be a bounded UTF-8 value")
  end
end

defimpl Inspect, for: Draught.CLI.Configuration.Credential do
  import Inspect.Algebra

  @spec inspect(Draught.CLI.Configuration.Credential.t(), Inspect.Opts.t()) ::
          Inspect.Algebra.t()
  def inspect(_credential, _options) do
    concat(["#Draught.CLI.Configuration.Credential<redacted>"])
  end
end
