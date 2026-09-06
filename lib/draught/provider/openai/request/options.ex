defmodule Draught.Provider.OpenAI.Request.Options do
  @moduledoc """
  Serializes explicitly configured generation options.
  """

  alias Draught.Provider.Options

  @doc "Encodes non-default generation settings without inventing provider values."
  @spec encode(Options.t()) :: map()
  def encode(%Options{} = options) do
    %{}
    |> put_optional("temperature", options.temperature)
    |> put_optional("max_completion_tokens", options.max_output_tokens)
    |> put_stop(options.stop)
    |> put_optional("seed", options.seed)
  end

  defp put_optional(values, _key, nil) do
    values
  end

  defp put_optional(values, key, value) do
    Map.put(values, key, value)
  end

  defp put_stop(values, []) do
    values
  end

  defp put_stop(values, stop) do
    Map.put(values, "stop", stop)
  end
end
