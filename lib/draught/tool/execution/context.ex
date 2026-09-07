defmodule Draught.Tool.Execution.Context do
  @moduledoc """
  Explicit workspace and policy passed to each tool invocation.
  """

  alias Draught.Tool.Approval.Policy.Adapter
  alias Draught.Tool.Approval.Policy.Default
  alias Draught.Tool.Execution.Policy
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @default_approval {Default, nil}

  @enforce_keys [:workspace, :policy, :approval]
  defstruct [:workspace, :policy, :approval]

  @type t :: %__MODULE__{
          workspace: String.t(),
          policy: Policy.t(),
          approval: Draught.Tool.Approval.policy()
        }

  @doc "Builds an execution context with an absolute workspace path."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes) do
    with {:ok, normalized} <- Attributes.normalize(attributes, [:workspace, :policy, :approval]),
         {:ok, workspace} <- workspace(normalized),
         {:ok, policy} <- policy(normalized),
         {:ok, approval} <- approval(normalized) do
      {:ok, %__MODULE__{workspace: workspace, policy: policy, approval: approval}}
    end
  end

  defp workspace(attributes) do
    with {:ok, workspace} <- Value.required_string(attributes, :workspace),
         :ok <- absolute(workspace) do
      {:ok, workspace}
    end
  end

  defp absolute(workspace) do
    workspace
    |> Path.type()
    |> absolute_result()
  end

  defp absolute_result(:absolute) do
    :ok
  end

  defp absolute_result(_type) do
    Error.single([:workspace], :invalid_value, "must be an absolute path")
  end

  defp policy(attributes) do
    case Map.get(attributes, :policy) do
      %Policy{} = policy ->
        policy
        |> Map.from_struct()
        |> Policy.new()

      nil ->
        Policy.new()

      _policy ->
        Error.single([:policy], :invalid_type, "must be an execution policy")
    end
  end

  defp approval(attributes) do
    approval = Map.get(attributes, :approval, @default_approval)

    case Adapter.validate(approval) do
      {:ok, _module, _configuration} -> {:ok, approval}
      {:error, _error} -> Error.single([:approval], :invalid_value, "must be an approval policy")
    end
  end
end
