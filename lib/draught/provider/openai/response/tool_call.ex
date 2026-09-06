defmodule Draught.Provider.OpenAI.Response.ToolCall do
  @moduledoc """
  Decodes complete function tool calls and their JSON arguments.
  """

  alias Draught.Error.Normalized
  alias Draught.Provider.OpenAI.Response.Protocol
  alias Draught.Tool.Call

  @doc "Decodes an optional ordered list of provider tool calls."
  @spec decode_all(term()) :: {:ok, [Call.t()]} | {:error, Normalized.t()}
  def decode_all(nil) do
    {:ok, []}
  end

  def decode_all(calls) when is_list(calls) do
    result =
      Enum.reduce_while(calls, {:ok, []}, fn call, {:ok, decoded} ->
        case decode(call) do
          {:ok, value} -> {:cont, {:ok, [value | decoded]}}
          {:error, %Normalized{}} = error -> {:halt, error}
        end
      end)

    reverse_calls(result)
  end

  def decode_all(_calls) do
    invalid_tool_call()
  end

  defp decode(%{
         "id" => id,
         "type" => "function",
         "function" => %{"name" => name, "arguments" => encoded_arguments}
       })
       when is_binary(encoded_arguments) do
    case Jason.decode(encoded_arguments) do
      {:ok, arguments} when is_map(arguments) -> build(id, name, arguments)
      _result -> invalid_tool_call()
    end
  end

  defp decode(_call) do
    invalid_tool_call()
  end

  defp build(id, name, arguments) do
    %{id: id, name: name, arguments: arguments}
    |> Call.new()
    |> Protocol.canonical("invalid_tool_call", "provider tool call is malformed")
  end

  defp reverse_calls({:ok, calls}) do
    {:ok, Enum.reverse(calls)}
  end

  defp reverse_calls({:error, %Normalized{}} = result) do
    result
  end

  defp invalid_tool_call do
    Protocol.error("invalid_tool_call", "provider tool call is malformed")
  end
end
