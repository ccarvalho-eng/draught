defmodule Draught.Conversation.Interchange.Text.Encoder.Message do
  @moduledoc """
  Converts canonical messages into ordered text-extension values.

  Each message role has a fixed encoded shape, including the explicit sentinel
  used for content-filtered assistant responses.
  """

  alias Draught.Conversation.Interchange.Text.Encoder.Message.Content
  alias Draught.Conversation.Interchange.Text.Encoder.Message.Tool
  alias Draught.Conversation.Interchange.Text.JSON
  alias Draught.Conversation.Interchange.Text.Options
  alias Draught.Conversation.Message.Assistant
  alias Draught.Conversation.Message.System
  alias Draught.Conversation.Message.User

  @doc "Converts a canonical message into an ordered JSON value."
  @spec encode(term(), Options.t()) :: term()
  def encode(%System{content: content}, _options) do
    text_message("system", content.text)
  end

  def encode(%User{content: content}, _options) do
    text_message("user", content.text)
  end

  def encode(%Assistant{content: [], tool_calls: []}, _options) do
    JSON.object([{"role", "assistant"}, {"filtered", true}])
  end

  def encode(%Assistant{} = message, options) do
    JSON.object([
      {"role", "assistant"},
      {"content", Enum.map(message.content, &Content.encode(&1, options))},
      {"tool_calls", Enum.map(message.tool_calls, &Tool.encode_call(&1, options))}
    ])
  end

  def encode(%Draught.Conversation.Message.Tool{result: result}, options) do
    JSON.object([{"role", "tool"}, {"result", Tool.encode_result(result, options)}])
  end

  defp text_message(role, content) do
    JSON.object([{"role", role}, {"content", content}])
  end
end
