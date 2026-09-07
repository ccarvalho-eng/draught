defmodule Draught.Web.Failure do
  @moduledoc false

  alias Draught.Error.Normalized

  @doc "Builds the failure for an operation excluded by the effective capability."
  @spec disabled(:fetch | :search) :: Normalized.t()
  def disabled(operation) do
    normalized(:policy, "web_#{operation}_disabled", "Web #{operation} is disabled")
  end

  @doc "Builds a safe adapter-contract failure."
  @spec invalid_result() :: Normalized.t()
  def invalid_result do
    normalized(:tool, "invalid_web_result", "Web adapter returned an invalid result")
  end

  @doc "Builds a safe network failure without transport details."
  @spec request_failed() :: Normalized.t()
  def request_failed do
    normalized(:tool, "web_request_failed", "Web request failed", retryable: true)
  end

  @doc "Builds the failure for a URL or resolved address excluded by egress policy."
  @spec target_blocked() :: Normalized.t()
  def target_blocked do
    normalized(:policy, "web_target_blocked", "Web target is blocked by egress policy")
  end

  @doc "Builds the failure for a response exceeding its byte budget."
  @spec response_too_large() :: Normalized.t()
  def response_too_large do
    normalized(:tool, "web_response_too_large", "Web response exceeds the configured byte limit")
  end

  @doc "Builds the failure for a response with unsupported content encoding."
  @spec content_encoding_rejected() :: Normalized.t()
  def content_encoding_rejected do
    normalized(
      :tool,
      "web_content_encoding_rejected",
      "Web response content encoding is not allowed"
    )
  end

  @doc "Builds the failure for a response with unsupported media type."
  @spec content_type_rejected() :: Normalized.t()
  def content_type_rejected do
    normalized(:tool, "web_content_type_rejected", "Web response content type is not allowed")
  end

  @doc "Builds the failure for malformed textual response content."
  @spec content_invalid() :: Normalized.t()
  def content_invalid do
    normalized(:tool, "web_content_invalid", "Web response content is invalid")
  end

  @doc "Builds the failure for an invalid or excessive redirect."
  @spec redirect_rejected() :: Normalized.t()
  def redirect_rejected do
    normalized(:policy, "web_redirect_rejected", "Web redirect is not allowed")
  end

  @doc "Builds the failure for an exhausted web-operation deadline."
  @spec timeout() :: Normalized.t()
  def timeout do
    normalized(:timeout, "web_timeout", "Web operation timed out", retryable: true)
  end

  defp normalized(kind, code, message, options \\ []) do
    {:ok, error} = Normalized.new(kind, code, message, options)
    error
  end
end
