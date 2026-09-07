defmodule Draught.Session.Journal.Codec.Message.Tool do
  @moduledoc """
  Encodes and decodes canonical tool-result messages for journal persistence.
  """

  alias Draught.Conversation.Message.Tool
  alias Draught.Session.Journal.Retention

  @doc "Encodes a canonical tool-result message."
  @spec encode(Tool.t(), Retention.t()) :: map()
  def encode(%Tool{result: result}, %Retention{} = retention) do
    encoded = Draught.Session.Journal.Codec.Tool.encode_result(result, retention)
    %{"result" => encoded, "role" => "tool"}
  end

  @doc "Decodes a canonical tool-result message."
  @spec decode(term()) :: {:ok, Tool.t()} | :error
  def decode(%{"result" => tool_result, "role" => "tool"}) do
    with {:ok, decoded_result} <-
           Draught.Session.Journal.Codec.Tool.decode_result(tool_result) do
      result(Tool.new(decoded_result))
    end
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
