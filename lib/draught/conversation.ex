defmodule Draught.Conversation do
  @moduledoc """
  Convenient constructors for provider-neutral conversation messages.
  """

  alias Draught.Conversation.Message.Assistant
  alias Draught.Conversation.Message.System
  alias Draught.Conversation.Message.Tool
  alias Draught.Conversation.Message.User
  alias Draught.Tool.Result
  alias Draught.Validation.Error

  @doc "Builds a system message from text."
  @spec system(String.t()) :: Error.result(System.t())
  def system(content) do
    System.new(content: content)
  end

  @doc "Builds a user message from text."
  @spec user(String.t()) :: Error.result(User.t())
  def user(content) do
    User.new(content: content)
  end

  @doc "Builds an assistant message from content and tool-call attributes."
  @spec assistant(map() | keyword()) :: Error.result(Assistant.t())
  def assistant(attributes) do
    Assistant.new(attributes)
  end

  @doc "Builds a tool message from a canonical tool result."
  @spec tool(Result.t() | map() | keyword()) :: Error.result(Tool.t())
  def tool(%Result{} = result) do
    Tool.new(result)
  end

  def tool(result) do
    with {:ok, canonical_result} <- Result.new(result) do
      Tool.new(canonical_result)
    end
  end
end
