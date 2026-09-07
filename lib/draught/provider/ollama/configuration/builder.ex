defmodule Draught.Provider.Ollama.Configuration.Builder do
  @moduledoc """
  Builds Ollama configuration from independently validated groups.

  It derives native discovery settings and an OpenAI-compatible endpoint from one
  base URL while preserving explicit model and capability requirements.
  """

  alias Draught.Provider.Ollama.Configuration
  alias Draught.Provider.Ollama.Configuration.Requirements
  alias Draught.Provider.Ollama.Discovery
  alias Draught.Provider.OpenAI
  alias Draught.Provider.OpenAI.Configuration.Endpoint
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error

  @keys [
    :base_url,
    :model,
    :required_capabilities,
    :headers,
    :timeouts,
    :retry,
    :limits,
    :reasoning_field
  ]
  @default_base_url "http://localhost:11434"

  @doc "Builds the Ollama configuration groups."
  @spec new(map() | keyword()) :: Error.result(Configuration.t())
  def new(attributes) do
    with {:ok, normalized} <- Attributes.normalize(attributes, @keys),
         {:ok, base_url} <- endpoint(normalized),
         {:ok, requirements} <- requirements(normalized),
         {:ok, openai} <- openai(normalized, base_url),
         {:ok, discovery} <- discovery(base_url, openai.timeouts) do
      {:ok,
       %Configuration{
         base_url: base_url,
         model: openai.model,
         required_capabilities: requirements,
         openai: openai,
         discovery: discovery
       }}
    end
  end

  defp endpoint(attributes) do
    attributes
    |> Map.get(:base_url, @default_base_url)
    |> Endpoint.new()
  end

  defp requirements(attributes) do
    attributes
    |> Map.get(:required_capabilities)
    |> requirements_value()
  end

  defp requirements_value(nil) do
    Requirements.new()
  end

  defp requirements_value(value) do
    Requirements.new(value)
  end

  defp openai(attributes, base_url) do
    options =
      attributes
      |> Map.drop([:base_url, :required_capabilities])
      |> Map.put(:base_url, base_url <> "/v1")
      |> Map.put_new(:reasoning_field, :reasoning)

    OpenAI.Configuration.new(options)
  end

  defp discovery(base_url, timeouts) do
    Discovery.Configuration.new(
      base_url: base_url,
      connect_timeout_ms: timeouts.connect_ms,
      receive_timeout_ms: timeouts.receive_ms,
      request_timeout_ms: timeouts.request_ms
    )
  end
end
