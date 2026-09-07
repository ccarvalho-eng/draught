defmodule Draught.Session.Journal.Codec.Message do
  @moduledoc """
  Dispatches retention-aware encoding and decoding for canonical conversation message roles.
  """

  alias Draught.Session.Journal.Codec.Message.Assistant
  alias Draught.Session.Journal.Codec.Message.Textual
  alias Draught.Session.Journal.Codec.Message.Tool
  alias Draught.Session.Journal.Retention

  @doc "Encodes a canonical conversation message."
  @spec encode(Draught.Conversation.Message.t(), Retention.t()) :: map()
  def encode(%Draught.Conversation.Message.System{} = message, %Retention{} = retention) do
    Textual.encode(message, retention)
  end

  def encode(%Draught.Conversation.Message.User{} = message, %Retention{} = retention) do
    Textual.encode(message, retention)
  end

  def encode(%Draught.Conversation.Message.Assistant{} = message, %Retention{} = retention) do
    Assistant.encode(message, retention)
  end

  def encode(%Draught.Conversation.Message.Tool{} = message, %Retention{} = retention) do
    Tool.encode(message, retention)
  end

  @doc "Decodes a string-keyed canonical conversation message."
  @spec decode(term()) :: {:ok, Draught.Conversation.Message.t()} | :error
  def decode(%{"role" => role} = data) when role in ["system", "user"] do
    Textual.decode(data)
  end

  def decode(%{"role" => "assistant"} = data) do
    Assistant.decode(data)
  end

  def decode(%{"role" => "tool"} = data) do
    Tool.decode(data)
  end

  def decode(_data) do
    :error
  end
end
