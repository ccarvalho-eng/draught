defmodule Draught.Web.Fetch.Transport.Configuration do
  @moduledoc false

  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Web.Fetch.Transport.Connection
  alias Draught.Web.Network.Resolver.System

  @default_resolver {System, nil}
  @default_connection {Connection.Mint, nil}

  @enforce_keys [:connection, :resolver]
  defstruct [:connection, :resolver]

  @type adapter :: {module(), term()}
  @type t :: %__MODULE__{connection: adapter(), resolver: adapter()}

  @doc "Builds explicit resolver and connection adapters."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes \\ %{}) do
    with {:ok, normalized} <- Attributes.normalize(attributes, [:connection, :resolver]),
         {:ok, resolver} <- adapter(normalized, :resolver, @default_resolver, :resolve, 2),
         {:ok, connection} <- adapter(normalized, :connection, @default_connection, :request, 4) do
      {:ok, %__MODULE__{connection: connection, resolver: resolver}}
    end
  end

  defp adapter(attributes, key, default, function, arity) do
    case Map.get(attributes, key, default) do
      {module, _configuration} = adapter when is_atom(module) ->
        valid = Code.ensure_loaded?(module) and function_exported?(module, function, arity)
        adapter_result(valid, adapter, key)

      _adapter ->
        invalid(key)
    end
  end

  defp adapter_result(true, adapter, _key) do
    {:ok, adapter}
  end

  defp adapter_result(false, _adapter, key) do
    invalid(key)
  end

  defp invalid(key) do
    Error.single([key], :invalid_value, "must implement the web transport adapter contract")
  end
end
