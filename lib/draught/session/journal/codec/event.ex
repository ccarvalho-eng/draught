defmodule Draught.Session.Journal.Codec.Event do
  @moduledoc """
  Converts the closed journal event set to and from stable string-keyed data.
  """

  alias Draught.Provider.Request
  alias Draught.Session.Journal.Codec.Message
  alias Draught.Session.Journal.Codec.Outcome
  alias Draught.Session.Journal.Codec.Tool
  alias Draught.Session.Journal.Retention

  @doc "Encodes one closed journal event into its stable type and data map."
  @spec encode(Draught.Session.Journal.Event.t(), Retention.t()) :: {String.t(), map()}
  def encode({:turn_started, turn_id, provider, %Request{} = request}, retention) do
    data = %{
      "messages" => Enum.map(request.messages, &Message.encode(&1, retention)),
      "model" => request.model,
      "provider" => provider,
      "turn_id" => turn_id
    }

    {"turn_started", data}
  end

  def encode({:provider_result, turn_id, iteration, outcome}, retention) do
    {"provider_result",
     %{
       "iteration" => iteration,
       "outcome" => Outcome.encode(outcome, retention),
       "turn_id" => turn_id
     }}
  end

  def encode({:tool_result, turn_id, iteration, result}, retention) do
    {"tool_result",
     %{
       "iteration" => iteration,
       "result" => Tool.encode_result(result, retention),
       "turn_id" => turn_id
     }}
  end

  def encode({:turn_terminal, turn_id, outcome}, retention) do
    {"turn_terminal", %{"outcome" => Outcome.encode(outcome, retention), "turn_id" => turn_id}}
  end

  @doc "Decodes one closed journal event."
  @spec decode(term(), term()) :: {:ok, Draught.Session.Journal.Event.t()} | :error
  def decode("turn_started", data) when is_map(data) do
    with {:ok, turn_id} <-
           data
           |> Map.get("turn_id")
           |> positive(),
         {:ok, provider} <-
           data
           |> Map.get("provider")
           |> required_string(),
         {:ok, model} <-
           data
           |> Map.get("model")
           |> required_string(),
         {:ok, messages} <-
           data
           |> Map.get("messages")
           |> messages(),
         {:ok, request} <- Request.new(model: model, messages: messages) do
      {:ok, {:turn_started, turn_id, provider, request}}
    else
      _result -> :error
    end
  end

  def decode("provider_result", data) when is_map(data) do
    with {:ok, turn_id} <-
           data
           |> Map.get("turn_id")
           |> positive(),
         {:ok, iteration} <-
           data
           |> Map.get("iteration")
           |> positive(),
         {:ok, outcome} <-
           data
           |> Map.get("outcome")
           |> Outcome.decode() do
      {:ok, {:provider_result, turn_id, iteration, outcome}}
    end
  end

  def decode("tool_result", data) when is_map(data) do
    with {:ok, turn_id} <-
           data
           |> Map.get("turn_id")
           |> positive(),
         {:ok, iteration} <-
           data
           |> Map.get("iteration")
           |> positive(),
         {:ok, result} <-
           data
           |> Map.get("result")
           |> Tool.decode_result() do
      {:ok, {:tool_result, turn_id, iteration, result}}
    end
  end

  def decode("turn_terminal", data) when is_map(data) do
    with {:ok, turn_id} <-
           data
           |> Map.get("turn_id")
           |> positive(),
         {:ok, outcome} <-
           data
           |> Map.get("outcome")
           |> Outcome.decode() do
      {:ok, {:turn_terminal, turn_id, outcome}}
    end
  end

  def decode(_type, _data) do
    :error
  end

  defp messages(values) when is_list(values) and values != [] do
    values
    |> Enum.reduce_while({:ok, []}, fn value, {:ok, decoded} ->
      case Message.decode(value) do
        {:ok, message} -> {:cont, {:ok, [message | decoded]}}
        :error -> {:halt, :error}
      end
    end)
    |> reverse()
  end

  defp messages(_values) do
    :error
  end

  defp reverse({:ok, values}) do
    {:ok, Enum.reverse(values)}
  end

  defp reverse(:error) do
    :error
  end

  defp positive(value) when is_integer(value) and value > 0 do
    {:ok, value}
  end

  defp positive(_value) do
    :error
  end

  defp required_string(value) when is_binary(value) and byte_size(value) > 0 do
    {:ok, value}
  end

  defp required_string(_value) do
    :error
  end
end
