defmodule Draught.Provider.OpenAI.Request.Encoder do
  @moduledoc """
  Serializes canonical provider requests into OpenAI-compatible request bodies.
  """

  alias Draught.Error.Normalized
  alias Draught.Provider.OpenAI.Configuration
  alias Draught.Provider.OpenAI.Request.Message
  alias Draught.Provider.OpenAI.Request.Options
  alias Draught.Provider.OpenAI.Request.Tool
  alias Draught.Provider.Request

  @type mode :: :complete | :stream

  @doc "Encodes a canonical request for a complete or streamed chat completion."
  @spec encode(Request.t(), Configuration.t(), mode()) ::
          {:ok, map()} | {:error, Normalized.t()}
  def encode(%Request{} = request, %Configuration{} = configuration, mode) do
    with {:ok, messages} <- Message.encode_all(request.messages, configuration.reasoning_field) do
      body =
        %{"model" => configuration.model || request.model, "messages" => messages}
        |> put_tools(request.tools)
        |> Map.merge(Options.encode(request.options))
        |> put_stream(mode)

      {:ok, body}
    end
  end

  defp put_tools(body, []) do
    body
  end

  defp put_tools(body, tools) do
    Map.put(body, "tools", Enum.map(tools, &Tool.encode/1))
  end

  defp put_stream(body, :complete) do
    body
  end

  defp put_stream(body, :stream) do
    body
    |> Map.put("stream", true)
    |> Map.put("stream_options", %{"include_usage" => true})
  end
end
