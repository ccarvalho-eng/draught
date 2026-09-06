defmodule Draught.Provider.Ollama.Protocol do
  @moduledoc false

  alias Draught.Error.Normalized
  alias Draught.Provider.Ollama.Discovery.HTTP.Failure

  @doc "Returns a sanitized malformed-discovery error."
  @spec invalid_response() :: {:error, Normalized.t()}
  def invalid_response do
    error(:protocol, "invalid_ollama_response", "Ollama returned an invalid discovery response")
  end

  @doc "Normalizes one discovery HTTP failure."
  @spec transport(Failure.t()) :: {:error, Normalized.t()}
  def transport(%Failure{reason: :timeout}) do
    error(:timeout, "ollama_timeout", "Ollama discovery timed out", retryable: true)
  end

  def transport(%Failure{reason: :response_too_large}) do
    error(:protocol, "ollama_response_too_large", "Ollama discovery response exceeded its limit")
  end

  def transport(%Failure{reason: :unavailable}) do
    error(
      :transport,
      "ollama_unavailable",
      "Ollama is unavailable",
      hint: "Start Ollama or configure its base URL.",
      retryable: true
    )
  end

  def transport(%Failure{reason: :unknown}) do
    error(:transport, "ollama_transport_failure", "Ollama discovery request failed")
  end

  @doc "Returns a sanitized missing-model error."
  @spec model_not_found() :: {:error, Normalized.t()}
  def model_not_found do
    error(
      :configuration,
      "ollama_model_not_found",
      "The configured Ollama model is not installed",
      hint: "Run `ollama pull <model>` with the configured model name."
    )
  end

  @doc "Returns a sanitized invalid-model error."
  @spec invalid_model() :: {:error, Normalized.t()}
  def invalid_model do
    error(:configuration, "invalid_ollama_model", "Ollama model must be a non-empty UTF-8 string")
  end

  @doc "Returns a sanitized invalid-discovery-client error."
  @spec invalid_http() :: {:error, Normalized.t()}
  def invalid_http do
    error(
      :configuration,
      "invalid_ollama_discovery_http",
      "Ollama discovery HTTP module is invalid"
    )
  end

  @doc "Returns a sanitized HTTP-status error."
  @spec http(non_neg_integer()) :: {:error, Normalized.t()}
  def http(status) do
    error(
      :transport,
      "ollama_http_#{status}",
      "Ollama discovery returned HTTP #{status}",
      retryable: status >= 500
    )
  end

  defp error(kind, code, message, options \\ []) do
    {:ok, error} = Normalized.new(kind, code, message, options)
    {:error, error}
  end
end
