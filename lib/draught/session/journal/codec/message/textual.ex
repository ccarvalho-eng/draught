defmodule Draught.Session.Journal.Codec.Message.Textual do
  @moduledoc false

  alias Draught.Conversation.Message.System
  alias Draught.Conversation.Message.User
  alias Draught.Session.Journal.Retention

  @doc "Encodes a canonical system or user text message."
  @spec encode(System.t() | User.t(), Retention.t()) :: map()
  def encode(%System{content: content}, %Retention{}) do
    %{"content" => content.text, "role" => "system"}
  end

  def encode(%User{content: content}, %Retention{}) do
    %{"content" => content.text, "role" => "user"}
  end

  @doc "Decodes a canonical system or user text message."
  @spec decode(term()) :: {:ok, System.t() | User.t()} | :error
  def decode(%{"content" => content, "role" => "system"}) do
    result(System.new(content: content))
  end

  def decode(%{"content" => content, "role" => "user"}) do
    result(User.new(content: content))
  end

  def decode(_data) do
    :error
  end

  defp result({:ok, value}) do
    {:ok, value}
  end

  defp result({:error, _error}) do
    :error
  end
end
