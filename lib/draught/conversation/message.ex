defmodule Draught.Conversation.Message do
  @moduledoc """
  Constructs and identifies the closed set of conversation message variants.
  """

  alias Draught.Conversation.Message.Assistant
  alias Draught.Conversation.Message.System
  alias Draught.Conversation.Message.Tool
  alias Draught.Conversation.Message.User
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @roles [:assistant, :system, :tool, :user]

  @type role :: :assistant | :system | :tool | :user
  @type t :: Assistant.t() | System.t() | Tool.t() | User.t()

  @doc "Builds a role-specific message from external attributes."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes) do
    with {:ok, normalized} <-
           Attributes.normalize(attributes, [:role, :content, :reasoning, :tool_calls, :result]),
         {:ok, raw_role} <- Attributes.fetch_required(normalized, :role),
         {:ok, role} <- Value.enum(raw_role, @roles, [:role]) do
      role
      |> build(Map.delete(normalized, :role))
      |> prefix_role_error(role)
    end
  end

  @doc "Validates a role-specific message, including manually constructed structs."
  @spec validate(term()) :: Error.result(t())
  def validate(%Assistant{} = message) do
    message
    |> Map.from_struct()
    |> Assistant.new()
  end

  def validate(%System{} = message) do
    message
    |> Map.from_struct()
    |> System.new()
  end

  def validate(%Tool{} = message) do
    message
    |> Map.from_struct()
    |> Tool.new()
  end

  def validate(%User{} = message) do
    message
    |> Map.from_struct()
    |> User.new()
  end

  def validate(_message) do
    Error.single([], :invalid_type, "must be a canonical message")
  end

  @doc "Returns the stable role derived from a message variant."
  @spec role(t()) :: role()
  def role(%Assistant{}) do
    :assistant
  end

  def role(%System{}) do
    :system
  end

  def role(%Tool{}) do
    :tool
  end

  def role(%User{}) do
    :user
  end

  defp build(:assistant, attributes) do
    Assistant.new(attributes)
  end

  defp build(:system, attributes) do
    System.new(attributes)
  end

  defp build(:tool, attributes) do
    Tool.new(attributes)
  end

  defp build(:user, attributes) do
    User.new(attributes)
  end

  defp prefix_role_error({:ok, _message} = result, _role) do
    result
  end

  defp prefix_role_error({:error, %Error{} = error}, role) do
    prefixed =
      Enum.map(error.violations, fn violation ->
        %{violation | path: [role | violation.path]}
      end)

    {:error, Error.new(prefixed)}
  end
end
