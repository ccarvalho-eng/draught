defmodule Draught.Web.Capability do
  @moduledoc """
  Explicit policy and adapters that grant web authority to one execution context.
  """

  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Web.Adapter
  alias Draught.Web.Policy

  @enforce_keys [:policy]
  defstruct [:policy, :search, :fetch]

  @type t :: %__MODULE__{
          policy: Policy.t(),
          search: {module(), term()} | nil,
          fetch: {module(), term()} | nil
        }

  @doc "Builds a disabled capability unless operations and adapters are explicit."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes \\ %{}) do
    with {:ok, normalized} <- Attributes.normalize(attributes, [:policy, :search, :fetch]),
         {:ok, policy} <- policy(normalized),
         {:ok, search} <- adapter(normalized, policy, :search),
         {:ok, fetch} <- adapter(normalized, policy, :fetch) do
      {:ok, %__MODULE__{policy: policy, search: search, fetch: fetch}}
    end
  end

  @doc "Builds a capability and raises when trusted application configuration is invalid."
  @spec new!(map() | keyword()) :: t()
  def new!(attributes \\ %{}) do
    case new(attributes) do
      {:ok, capability} -> capability
      {:error, error} -> raise ArgumentError, message: inspect(error)
    end
  end

  @doc "Returns whether one operation has both permission and an adapter."
  @spec enabled?(t(), Policy.operation()) :: boolean()
  def enabled?(%__MODULE__{policy: policy} = capability, operation) do
    Policy.enabled?(policy, operation) and not is_nil(Map.fetch!(capability, operation))
  end

  @doc "Returns the adapter for an enabled operation."
  @spec fetch_adapter(t(), Policy.operation()) :: {:ok, {module(), term()}} | :error
  def fetch_adapter(%__MODULE__{} = capability, operation) do
    capability
    |> enabled?(operation)
    |> adapter_result(capability, operation)
  end

  defp policy(%{policy: %Policy{} = policy}) do
    policy
    |> Map.from_struct()
    |> Policy.new()
  end

  defp policy(%{policy: policy}) do
    Policy.new(policy)
  end

  defp policy(_attributes) do
    Policy.new()
  end

  defp adapter(attributes, policy, operation) do
    value = Map.get(attributes, operation)

    cond do
      is_nil(value) and Policy.enabled?(policy, operation) ->
        Error.single([operation], :required, "is required when the operation is enabled")

      is_nil(value) ->
        {:ok, nil}

      true ->
        Adapter.validate(value, operation)
    end
  end

  defp adapter_result(true, capability, operation) do
    Map.fetch(capability, operation)
  end

  defp adapter_result(false, _capability, _operation) do
    :error
  end
end
