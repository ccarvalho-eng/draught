defmodule Draught.Session.Journal.Codec.Tool do
  @moduledoc false

  alias Draught.Session.Journal.Codec.Error
  alias Draught.Session.Journal.Retention
  alias Draught.Tool.Call
  alias Draught.Tool.Result

  @doc "Encodes a tool call under the configured retention policy."
  @spec encode_call(Call.t(), Retention.t()) :: map()
  def encode_call(%Call{} = call, %Retention{} = retention) do
    %{
      "arguments" => retained(call.arguments, retention.tool_arguments, %{}),
      "arguments_retained" => retention.tool_arguments == :retain,
      "id" => call.id,
      "name" => call.name
    }
  end

  @doc "Decodes a retained or redacted canonical tool call."
  @spec decode_call(term()) :: {:ok, Call.t()} | :error
  def decode_call(data) when is_map(data) do
    data
    |> Map.take(["arguments", "id", "name"])
    |> Call.new()
    |> result()
  end

  def decode_call(_data) do
    :error
  end

  @doc "Encodes a tool result under the configured retention policy."
  @spec encode_result(Result.t(), Retention.t()) :: map()
  def encode_result(%Result{} = result, %Retention{} = retention) do
    %{
      "call_id" => result.call_id,
      "content" => retained(result.content, retention.tool_output, ""),
      "content_retained" => retention.tool_output == :retain,
      "error" => encode_optional_error(result.error),
      "name" => result.name,
      "status" => Atom.to_string(result.status)
    }
  end

  @doc "Decodes a retained or redacted canonical tool result."
  @spec decode_result(term()) :: {:ok, Result.t()} | :error
  def decode_result(data) when is_map(data) do
    with {:ok, status} <- status(Map.get(data, "status")),
         {:ok, error} <- decode_optional_error(Map.get(data, "error")) do
      data
      |> Map.take(["call_id", "content", "name"])
      |> Map.put("status", status)
      |> Map.put("error", error)
      |> Result.new()
      |> result()
    end
  end

  def decode_result(_data) do
    :error
  end

  defp retained(value, :retain, _replacement) do
    value
  end

  defp retained(_value, :omit, replacement) do
    replacement
  end

  defp encode_optional_error(nil) do
    nil
  end

  defp encode_optional_error(error) do
    Error.encode(error)
  end

  defp decode_optional_error(nil) do
    {:ok, nil}
  end

  defp decode_optional_error(data) do
    Error.decode(data)
  end

  defp status("success") do
    {:ok, :success}
  end

  defp status("error") do
    {:ok, :error}
  end

  defp status(_status) do
    :error
  end

  defp result({:ok, value}) do
    {:ok, value}
  end

  defp result({:error, _error}) do
    :error
  end
end
