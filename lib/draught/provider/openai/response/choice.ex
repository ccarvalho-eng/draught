defmodule Draught.Provider.OpenAI.Response.Choice do
  @moduledoc """
  Decodes the single supported chat completion choice.
  """

  alias Draught.Error.Normalized
  alias Draught.Provider.OpenAI.Response.Message
  alias Draught.Provider.OpenAI.Response.Protocol

  @finish_reasons %{
    "content_filter" => :content_filter,
    "length" => :length,
    "stop" => :stop,
    "tool_calls" => :tool_calls
  }

  @doc "Decodes choice zero and its finish reason."
  @spec decode(term()) ::
          {:ok,
           {Draught.Conversation.Message.Assistant.t(), Draught.Provider.Response.finish_reason()}}
          | {:error, Normalized.t()}
  def decode(%{"index" => 0, "message" => message, "finish_reason" => raw_reason}) do
    with {:ok, finish_reason} <- finish_reason(raw_reason),
         {:ok, assistant} <- Message.decode(message, finish_reason) do
      {:ok, {assistant, finish_reason}}
    end
  end

  def decode(_choice) do
    Protocol.error("invalid_choice", "provider choice is malformed")
  end

  defp finish_reason(reason) when is_binary(reason) do
    {:ok, Map.get(@finish_reasons, reason, :other)}
  end

  defp finish_reason(_reason) do
    Protocol.error("invalid_choice", "provider choice has no final finish reason")
  end
end
