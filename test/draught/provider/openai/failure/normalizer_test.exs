defmodule Draught.Provider.OpenAI.Failure.NormalizerTest do
  use ExUnit.Case, async: true

  alias Draught.Provider.OpenAI.Failure.Normalizer
  alias Draught.Provider.OpenAI.Transport.Failure

  test "classifies only the supported HTTP statuses as retryable" do
    retryable = [408, 429, 500, 502, 503, 504]

    Enum.each(retryable, fn status ->
      error = Normalizer.http(status)
      assert error.kind == :transport
      assert error.code == "http_#{status}"
      assert error.retryable
    end)

    Enum.each([301, 400, 401, 403, 404, 422, 501], fn status ->
      refute Normalizer.http(status).retryable
    end)
  end

  test "normalizes transport failures without retaining external details" do
    expectations = [
      timeout: {:timeout, "transport_timeout", true},
      connection_refused: {:transport, "connection_refused", true},
      closed: {:transport, "connection_closed", true},
      unprocessed: {:transport, "request_unprocessed", true},
      response_too_large: {:protocol, "response_too_large", false},
      unknown: {:transport, "transport_failed", false}
    ]

    Enum.each(expectations, fn {reason, {kind, code, retryable}} ->
      normalized = Normalizer.transport(Failure.new(reason))
      assert normalized.kind == kind
      assert normalized.code == code
      assert normalized.retryable == retryable
    end)
  end
end
