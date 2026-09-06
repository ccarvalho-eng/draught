defmodule Draught.Conversation.Message.TextContent do
  @moduledoc """
  Validates the shared text content contract for system and user messages.
  """

  alias Draught.Conversation.Content
  alias Draught.Conversation.Content.Text
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error

  @doc "Extracts one required canonical text part from message attributes."
  @spec new(map() | keyword()) :: Error.result(Text.t())
  def new(attributes) do
    with {:ok, normalized} <- Attributes.normalize(attributes, [:content]),
         {:ok, raw_content} <- Attributes.fetch_required(normalized, :content) do
      Content.text(raw_content)
    end
  end
end
