defmodule Draught.Provider.OpenAI.Response.Usage do
  @moduledoc """
  Decodes OpenAI and compatible token-usage fields.
  """

  alias Draught.Error.Normalized
  alias Draught.Provider.OpenAI.Protocol
  alias Draught.Provider.Usage

  @doc "Decodes optional token usage and supported detail fields."
  @spec decode(term()) :: {:ok, Usage.t() | nil} | {:error, Normalized.t()}
  def decode(nil) do
    {:ok, nil}
  end

  def decode(%{} = usage) do
    with {:ok, prompt_details} <- details(Map.get(usage, "prompt_tokens_details")),
         {:ok, completion_details} <- details(Map.get(usage, "completion_tokens_details")),
         {:ok, cached_tokens} <- cached_tokens(usage, prompt_details) do
      usage
      |> attributes(completion_details, cached_tokens)
      |> Usage.new()
      |> Protocol.canonical("invalid_usage", "provider usage is malformed")
    end
  end

  def decode(_usage) do
    invalid_usage()
  end

  defp details(nil) do
    {:ok, %{}}
  end

  defp details(%{} = details) do
    {:ok, details}
  end

  defp details(_details) do
    invalid_usage()
  end

  defp cached_tokens(usage, prompt_details) do
    top_level = Map.get(usage, "prompt_cache_hit_tokens")
    nested = Map.get(prompt_details, "cached_tokens")
    select_cached_tokens(top_level, nested)
  end

  defp select_cached_tokens(nil, nil) do
    {:ok, 0}
  end

  defp select_cached_tokens(nil, nested) do
    {:ok, nested}
  end

  defp select_cached_tokens(top_level, nil) do
    {:ok, top_level}
  end

  defp select_cached_tokens(value, value) do
    {:ok, value}
  end

  defp select_cached_tokens(_top_level, _nested) do
    invalid_usage()
  end

  defp attributes(usage, completion_details, cached_tokens) do
    attributes = [
      input_tokens: Map.get(usage, "prompt_tokens"),
      output_tokens: Map.get(usage, "completion_tokens"),
      cached_tokens: cached_tokens,
      reasoning_tokens: Map.get(completion_details, "reasoning_tokens", 0)
    ]

    put_total_tokens(attributes, usage)
  end

  defp put_total_tokens(attributes, %{"total_tokens" => total_tokens}) do
    Keyword.put(attributes, :total_tokens, total_tokens)
  end

  defp put_total_tokens(attributes, _usage) do
    attributes
  end

  defp invalid_usage do
    Protocol.error("invalid_usage", "provider usage is malformed")
  end
end
