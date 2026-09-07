defmodule Draught.Session.Journal.Codec.Response do
  @moduledoc false

  alias Draught.Provider.Response
  alias Draught.Provider.Usage
  alias Draught.Session.Journal.Codec.Message
  alias Draught.Session.Journal.Retention

  @doc "Encodes a canonical provider response."
  @spec encode(Response.t(), Retention.t()) :: map()
  def encode(%Response{} = response, %Retention{} = retention) do
    %{
      "finish_reason" => Atom.to_string(response.finish_reason),
      "message" => Message.encode(response.message, retention),
      "usage" => encode_usage(response.usage)
    }
  end

  @doc "Decodes a canonical provider response."
  @spec decode(term()) :: {:ok, Response.t()} | :error
  def decode(data) when is_map(data) do
    with {:ok, finish_reason} <-
           data
           |> Map.get("finish_reason")
           |> finish_reason(),
         {:ok, message} <-
           data
           |> Map.get("message")
           |> Message.decode(),
         {:ok, usage} <-
           data
           |> Map.get("usage")
           |> decode_usage() do
      result(Response.new(message: message, finish_reason: finish_reason, usage: usage))
    end
  end

  def decode(_data) do
    :error
  end

  defp encode_usage(nil) do
    nil
  end

  defp encode_usage(%Usage{} = usage) do
    usage
    |> Map.from_struct()
    |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end)
  end

  defp decode_usage(nil) do
    {:ok, nil}
  end

  defp decode_usage(data) when is_map(data) do
    result(Usage.new(data))
  end

  defp decode_usage(_data) do
    :error
  end

  defp finish_reason("content_filter") do
    {:ok, :content_filter}
  end

  defp finish_reason("length") do
    {:ok, :length}
  end

  defp finish_reason("other") do
    {:ok, :other}
  end

  defp finish_reason("stop") do
    {:ok, :stop}
  end

  defp finish_reason("tool_calls") do
    {:ok, :tool_calls}
  end

  defp finish_reason(_reason) do
    :error
  end

  defp result({:ok, value}) do
    {:ok, value}
  end

  defp result({:error, _error}) do
    :error
  end
end
