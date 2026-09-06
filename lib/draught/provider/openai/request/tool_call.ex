defmodule Draught.Provider.OpenAI.Request.ToolCall do
  @moduledoc """
  Serializes canonical assistant tool calls.
  """

  alias Draught.Tool.Call

  @doc "Encodes one function tool call and its JSON arguments."
  @spec encode(Call.t()) :: map()
  def encode(%Call{} = call) do
    %{
      "id" => call.id,
      "type" => "function",
      "function" => %{
        "name" => call.name,
        "arguments" => Jason.encode!(call.arguments)
      }
    }
  end
end
