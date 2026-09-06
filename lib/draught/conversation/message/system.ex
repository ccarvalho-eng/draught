defmodule Draught.Conversation.Message.System do
  @moduledoc """
  A system instruction represented by validated text content.
  """

  alias Draught.Conversation.Content.Text
  alias Draught.Conversation.Message.TextContent
  alias Draught.Validation.Error

  @enforce_keys [:content]
  defstruct [:content]

  @type t :: %__MODULE__{content: Text.t()}

  @doc "Builds a validated system message."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes) do
    with {:ok, content} <- TextContent.new(attributes) do
      {:ok, %__MODULE__{content: content}}
    end
  end
end
