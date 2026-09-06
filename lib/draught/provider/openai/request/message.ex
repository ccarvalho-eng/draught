defmodule Draught.Provider.OpenAI.Request.Message do
  @moduledoc """
  Serializes canonical conversation message variants.
  """

  alias Draught.Conversation.Content.Text
  alias Draught.Conversation.Message.System
  alias Draught.Conversation.Message.Tool
  alias Draught.Conversation.Message.User
  alias Draught.Error.Normalized
  alias Draught.Provider.OpenAI.Request.Message.Assistant

  @type reasoning_field :: :none | :reasoning | :reasoning_content

  @doc "Encodes canonical messages with the selected reasoning compatibility field."
  @spec encode_all([Draught.Conversation.Message.t()], reasoning_field()) ::
          {:ok, [map()]} | {:error, Normalized.t()}
  def encode_all(messages, reasoning_field) do
    result =
      Enum.reduce_while(messages, {:ok, []}, fn message, {:ok, encoded} ->
        case encode(message, reasoning_field) do
          {:ok, value} -> {:cont, {:ok, [value | encoded]}}
          {:error, %Normalized{}} = error -> {:halt, error}
        end
      end)

    reverse_messages(result)
  end

  @doc "Encodes one canonical message with the selected reasoning compatibility field."
  @spec encode(Draught.Conversation.Message.t(), reasoning_field()) ::
          {:ok, map()} | {:error, Normalized.t()}
  def encode(%System{content: %Text{text: text}}, _reasoning_field) do
    {:ok, %{"role" => "system", "content" => text}}
  end

  def encode(%User{content: %Text{text: text}}, _reasoning_field) do
    {:ok, %{"role" => "user", "content" => text}}
  end

  def encode(%Draught.Conversation.Message.Assistant{} = message, reasoning_field) do
    Assistant.encode(message, reasoning_field)
  end

  def encode(%Tool{result: result}, _reasoning_field) do
    {:ok,
     %{
       "role" => "tool",
       "tool_call_id" => result.call_id,
       "content" => result.content
     }}
  end

  defp reverse_messages({:ok, messages}) do
    {:ok, Enum.reverse(messages)}
  end

  defp reverse_messages({:error, %Normalized{}} = result) do
    result
  end
end
