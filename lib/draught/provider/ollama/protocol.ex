defmodule Draught.Provider.Ollama.Protocol do
  @moduledoc """
  Constructs normalized failures for Ollama discovery and model selection.

  The constructors expose stable error codes and hints while excluding raw
  discovery responses and transport details.
  """

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

  @doc "Returns an error when installed models do not satisfy the required capabilities."
  @spec no_compatible_models() :: {:error, Normalized.t()}
  def no_compatible_models do
    error(
      :capability,
      "ollama_no_compatible_models",
      "No installed Ollama model supports every required capability",
      hint: "Install a model that advertises every required capability."
    )
  end

  @doc "Returns an error when the installed-model inventory exceeds its diagnostic bound."
  @spec inventory_too_large() :: {:error, Normalized.t()}
  def inventory_too_large do
    error(
      :configuration,
      "ollama_inventory_too_large",
      "Ollama has more installed models than Draught can inspect in one operation",
      hint: "Select a model explicitly or reduce the installed model inventory."
    )
  end

  @doc "Returns an error when automatic selection is ambiguous."
  @spec model_required() :: {:error, Normalized.t()}
  def model_required do
    error(
      :configuration,
      "ollama_model_required",
      "More than one compatible Ollama model is installed",
      hint: "Select one of the compatible installed models explicitly."
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

  @doc "Returns a recoverable error when Ollama leaks tool-call markup as text."
  @spec malformed_tool_call() :: {:error, Normalized.t()}
  def malformed_tool_call do
    error(
      :protocol,
      "ollama_malformed_tool_call",
      "Ollama returned tool-call markup as assistant text",
      hint:
        "Retry the turn or start a new session if the model continues returning malformed calls.",
      retryable: true
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
