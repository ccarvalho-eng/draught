defmodule Draught.Provider.Ollama.Protocol do
  @moduledoc false

  alias Draught.Error.Normalized
  alias Draught.Provider.Capabilities
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

  @doc "Returns an error when no local model can be selected."
  @spec no_models() :: {:error, Normalized.t()}
  def no_models do
    error(
      :configuration,
      "ollama_no_models",
      "Ollama has no installed models",
      hint: "Install a model with `ollama pull <model>`."
    )
  end

  @doc "Returns an error when automatic selection is ambiguous."
  @spec model_required() :: {:error, Normalized.t()}
  def model_required do
    error(
      :configuration,
      "ollama_model_required",
      "More than one Ollama model is installed",
      hint: "Set the model explicitly."
    )
  end

  @doc "Returns an error for a missing model capability."
  @spec unsupported(Capabilities.feature()) :: {:error, Normalized.t()}
  def unsupported(feature) do
    error(
      :capability,
      "ollama_unsupported_#{feature}",
      "The selected Ollama model does not support #{feature}",
      hint: "Select a model that advertises the required capability."
    )
  end

  @doc "Returns an error for an invalid Ollama runtime value."
  @spec invalid_runtime() :: {:error, Normalized.t()}
  def invalid_runtime do
    error(:configuration, "invalid_ollama_runtime", "Ollama runtime is invalid")
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
