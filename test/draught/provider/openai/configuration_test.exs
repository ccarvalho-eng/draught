defmodule Draught.Provider.OpenAI.ConfigurationTest do
  use ExUnit.Case, async: true

  alias Draught.Provider.OpenAI.Configuration
  alias Draught.Provider.OpenAI.Configuration.Credential
  alias Draught.Provider.OpenAI.Configuration.Limits
  alias Draught.Provider.OpenAI.Configuration.Retry
  alias Draught.Provider.OpenAI.Configuration.Timeouts
  alias Draught.Validation.Error

  describe "credentials" do
    test "retain the secret while redacting inspection" do
      assert {:ok, credential} = Credential.new("top-secret")

      assert Credential.value(credential) == "top-secret"
      assert inspect(credential) == "#Draught.Provider.OpenAI.Configuration.Credential<redacted>"
      refute inspect(credential) =~ "top-secret"
    end

    test "reject malformed values without retaining them in the error" do
      invalid = <<255>>

      assert {:error, %Error{} = error} = Credential.new(invalid)
      refute inspect(error) =~ inspect(invalid)
      assert {:error, %Error{}} = Credential.new("")
      assert {:error, %Error{}} = Credential.new(:secret)
    end
  end

  describe "configuration" do
    test "uses bounded defaults" do
      assert {:ok, configuration} = Configuration.new()

      assert configuration.base_url == "https://api.openai.com/v1"
      assert configuration.model == nil
      assert configuration.credential == nil
      assert configuration.headers == %{}
      assert configuration.reasoning_field == :none

      assert configuration.timeouts == %Timeouts{
               connect_ms: 10_000,
               receive_ms: 60_000,
               request_ms: 120_000
             }

      assert configuration.retry == %Retry{max_attempts: 3, fixed_delay_ms: 250}

      assert configuration.limits == %Limits{
               max_response_bytes: 16_777_216,
               max_event_bytes: 1_048_576,
               max_output_bytes: 16_777_216,
               max_output_fragments: 65_536,
               max_calls: 128,
               max_arguments_bytes: 4_194_304
             }
    end

    test "normalizes endpoint, model, credential, headers, timeouts, and retry settings" do
      assert {:ok, configuration} =
               Configuration.new(
                 base_url: "http://localhost:11434/v1/",
                 model: "qwen3:8b",
                 credential: "ollama-local",
                 headers: %{"X-Title" => "private-title", "x-trace" => "enabled"},
                 reasoning_field: :reasoning_content,
                 timeouts: %{connect_ms: 500, receive_ms: 1_000, request_ms: 2_000},
                 retry: %{max_attempts: 2, fixed_delay_ms: 0},
                 limits: %{max_response_bytes: 2_048, max_output_fragments: 16}
               )

      assert configuration.base_url == "http://localhost:11434/v1"
      assert configuration.model == "qwen3:8b"
      assert Credential.value(configuration.credential) == "ollama-local"
      assert configuration.headers == %{"x-title" => "private-title", "x-trace" => "enabled"}
      assert configuration.reasoning_field == :reasoning_content
      assert configuration.timeouts.receive_ms == 1_000
      assert configuration.retry.max_attempts == 2
      assert configuration.limits.max_response_bytes == 2_048
      assert configuration.limits.max_output_fragments == 16
      refute inspect(configuration) =~ "ollama-local"
      refute inspect(configuration) =~ "private-title"
    end

    test "accepts a prevalidated credential and string keys" do
      assert {:ok, credential} = Credential.new("secret")

      assert {:ok, configuration} =
               Configuration.new(%{
                 "credential" => credential,
                 "reasoning_field" => "reasoning",
                 "headers" => %{"x-api-key" => "value"}
               })

      assert configuration.credential == credential
      assert configuration.reasoning_field == :reasoning
    end

    test "rejects unsafe or malformed endpoints" do
      invalid = [
        "ftp://api.example.test/v1",
        "https://user:secret@api.example.test/v1",
        "https://api.example.test/v1?token=secret",
        "https://api.example.test/v1#fragment",
        "not a URL"
      ]

      Enum.each(invalid, fn base_url ->
        assert {:error, %Error{}} = Configuration.new(base_url: base_url)
      end)
    end

    test "rejects reserved, duplicate, and injection-prone headers" do
      invalid = [
        %{"host" => "api.example.test"},
        %{"content-type" => "text/plain"},
        %{"bad header" => "value"},
        %{"x-safe" => "value\r\ninjected: true"},
        [{"X-Test", "one"}, {"x-test", "two"}]
      ]

      Enum.each(invalid, fn headers ->
        assert {:error, %Error{}} = Configuration.new(headers: headers)
      end)
    end

    test "does not allow two authorization sources" do
      assert {:ok, configuration} =
               Configuration.new(headers: %{"authorization" => "Bearer custom"})

      assert configuration.headers["authorization"] == "Bearer custom"
      refute inspect(configuration) =~ "Bearer custom"

      assert {:error, %Error{}} =
               Configuration.new(
                 credential: "secret",
                 headers: %{"authorization" => "Bearer custom"}
               )
    end

    test "rejects unbounded timeout and retry values" do
      invalid = [
        [base_url: false],
        [timeouts: %{connect_ms: 0}],
        [timeouts: %{receive_ms: 600_001}],
        [timeouts: %{request_ms: :infinity}],
        [retry: %{max_attempts: 0}],
        [retry: %{max_attempts: 5}],
        [retry: %{fixed_delay_ms: 5_001}],
        [limits: %{max_response_bytes: 0}],
        [limits: %{max_event_bytes: 8_388_609}],
        [limits: %{max_output_fragments: 1_048_577}],
        [limits: %{max_calls: 1_025}],
        [limits: %{unknown: 1}],
        [reasoning_field: :unknown],
        [model: ""]
      ]

      Enum.each(invalid, fn attributes ->
        assert {:error, %Error{}} = Configuration.new(attributes)
      end)
    end
  end
end
