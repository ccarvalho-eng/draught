defmodule Draught.Provider.OpenAI.Failure.Normalizer do
  @moduledoc """
  Converts HTTP and transport failures into safe provider-neutral errors.
  """

  alias Draught.Error.Normalized
  alias Draught.Provider.OpenAI.Transport.Failure

  @retryable_statuses [408, 429, 500, 502, 503, 504]

  @doc "Normalizes an HTTP status without retaining its response body."
  @spec http(non_neg_integer()) :: Normalized.t()
  def http(status) do
    normalized(
      :transport,
      "http_#{status}",
      "Provider returned HTTP status #{status}",
      status in @retryable_statuses
    )
  end

  @doc "Normalizes a sanitized transport failure and its retry classification."
  @spec transport(Failure.t()) :: Normalized.t()
  def transport(%Failure{reason: :timeout}) do
    normalized(:timeout, "transport_timeout", "Provider request timed out", true)
  end

  def transport(%Failure{reason: :connection_refused}) do
    normalized(:transport, "connection_refused", "Provider connection was refused", true)
  end

  def transport(%Failure{reason: :closed}) do
    normalized(:transport, "connection_closed", "Provider connection closed", true)
  end

  def transport(%Failure{reason: :unprocessed}) do
    normalized(:transport, "request_unprocessed", "Provider did not process the request", true)
  end

  def transport(%Failure{reason: :response_too_large}) do
    normalized(
      :protocol,
      "response_too_large",
      "Provider response exceeded the byte limit",
      false
    )
  end

  def transport(%Failure{reason: :unknown}) do
    normalized(:transport, "transport_failed", "Provider transport failed", false)
  end

  defp normalized(kind, code, message, retryable) do
    {:ok, error} = Normalized.new(kind, code, message, retryable: retryable)
    error
  end
end
