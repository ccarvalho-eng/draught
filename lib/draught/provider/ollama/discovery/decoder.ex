defmodule Draught.Provider.Ollama.Discovery.Decoder do
  @moduledoc false

  alias Draught.Provider.Capabilities
  alias Draught.Provider.Ollama.Discovery.Model
  alias Draught.Provider.Ollama.Protocol

  @doc "Decodes a native model-list payload."
  @spec list(binary()) :: {:ok, [String.t()]} | {:error, Draught.Error.Normalized.t()}
  def list(body) do
    with {:ok, %{"models" => models}} when is_list(models) <- Jason.decode(body),
         {:ok, names} <- names(models) do
      {:ok, names}
    else
      _invalid -> Protocol.invalid_response()
    end
  end

  @doc "Decodes native model details into canonical capabilities."
  @spec model(String.t(), binary()) :: {:ok, Model.t()} | {:error, Draught.Error.Normalized.t()}
  def model(name, body) do
    with {:ok, payload} when is_map(payload) <- Jason.decode(body),
         capabilities when is_list(capabilities) <- Map.get(payload, "capabilities"),
         {:ok, canonical} <- canonical_capabilities(capabilities, payload) do
      {:ok, %Model{name: name, capabilities: canonical}}
    else
      _invalid -> Protocol.invalid_response()
    end
  end

  defp names(models) do
    result =
      Enum.reduce_while(models, {:ok, []}, fn model, {:ok, names} ->
        case model_name(model) do
          {:ok, name} -> {:cont, {:ok, [name | names]}}
          :error -> {:halt, :error}
        end
      end)

    names_result(result)
  end

  defp model_name(%{"name" => name}) when is_binary(name) and byte_size(name) > 0 do
    {:ok, name}
  end

  defp model_name(%{"model" => name}) when is_binary(name) and byte_size(name) > 0 do
    {:ok, name}
  end

  defp model_name(_model) do
    :error
  end

  defp names_result({:ok, names}) do
    {:ok, Enum.reverse(names)}
  end

  defp names_result(:error) do
    :error
  end

  defp canonical_capabilities(capabilities, payload) do
    completion = "completion" in capabilities

    Capabilities.new(
      chat: completion,
      streaming: completion,
      tool_calls: "tools" in capabilities,
      reasoning: "thinking" in capabilities,
      usage: completion,
      context_window: context_window(payload)
    )
  end

  defp context_window(%{"model_info" => model_info}) when is_map(model_info) do
    architecture = Map.get(model_info, "general.architecture")
    context_value(model_info, architecture)
  end

  defp context_window(_payload) do
    nil
  end

  defp context_value(model_info, architecture) when is_binary(architecture) do
    case Map.get(model_info, architecture <> ".context_length") do
      value when is_integer(value) and value > 0 -> value
      _value -> fallback_context_value(model_info)
    end
  end

  defp context_value(model_info, _architecture) do
    fallback_context_value(model_info)
  end

  defp fallback_context_value(model_info) do
    values =
      Enum.flat_map(model_info, fn
        {key, value} when is_integer(value) and value > 0 ->
          key
          |> String.ends_with?(".context_length")
          |> context_entry(value)

        _entry ->
          []
      end)

    Enum.max(values, fn -> nil end)
  end

  defp context_entry(true, value) do
    [value]
  end

  defp context_entry(false, _value) do
    []
  end
end
