defmodule Draught.CLI.ConfigurationTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Configuration
  alias Draught.CLI.Configuration.Credential
  alias Draught.CLI.Configuration.Error

  describe "decoding" do
    test "rejects oversized, deeply nested, duplicate, and non-object JSON" do
      oversized = Jason.encode!(%{"model" => String.duplicate("a", 65_536)})

      deeply_nested =
        "{\"profiles\":{\"local\":{\"headers\":{\"x\":[[[[[[[]]]]]]]}}}}"

      assert {:error, %Error{code: :too_large}} = Configuration.decode(:user, oversized)
      assert {:error, %Error{code: :too_deep}} = Configuration.decode(:user, deeply_nested)

      assert {:error, %Error{code: :duplicate_key}} =
               Configuration.decode(:user, ~s({"model":"first","model":"second"}))

      assert {:error, %Error{code: :invalid_type}} = Configuration.decode(:user, "[]")
    end

    test "does not create atoms from unknown keys" do
      unknown = "untrusted_#{System.unique_integer([:positive])}"

      assert_raise ArgumentError, fn -> String.to_existing_atom(unknown) end

      assert {:error, %Error{code: :unknown_key}} =
               Configuration.decode(:project, Jason.encode!(%{unknown => true}))

      assert_raise ArgumentError, fn -> String.to_existing_atom(unknown) end
    end

    test "rejects terminal-affecting Unicode in displayable settings" do
      for codepoint <- [0x061C, 0x200E, 0x200F, 0x206A, 0x206F] do
        value = "model" <> <<codepoint::utf8>>

        assert {:error, %Error{code: :invalid_value}} =
                 Configuration.decode(:user, Jason.encode!(%{"model" => value}))
      end
    end

    test "rejects API keys and module injection in every data source" do
      Enum.each([:defaults, :user, :project, :environment, :flags], fn kind ->
        assert {:error, %Error{code: :unknown_key}} =
                 Configuration.decode(kind, ~s({"api_key":"secret"}))

        assert {:error, %Error{code: :unknown_key}} =
                 Configuration.decode(kind, ~s({"module":"Elixir.Untrusted"}))
      end)
    end
  end

  describe "authority and precedence" do
    test "resolves fixed precedence independently of input order" do
      defaults = decode!(:defaults, defaults_json())
      user = decode!(:user, ~s({"model":"user","web":true,"risk":"allow"}))
      project = decode!(:project, ~s({"model":"project","web":false,"risk":"deny"}))
      environment = decode!(:environment, ~s({"model":"environment","web":true,"risk":"ask"}))
      flags = decode!(:flags, ~s({"model":"flags","risk":"allow"}))

      assert {:ok, configuration} =
               Configuration.resolve([flags, project, defaults, environment, user])

      assert configuration.profile == "local"
      assert configuration.model == "flags"
      assert configuration.web
      assert configuration.risk == :allow
      assert configuration.origins.model == :flags
      assert configuration.origins.web == :environment
    end

    test "allows a project to narrow authority and select a model" do
      defaults = decode!(:defaults, defaults_json())

      project =
        decode!(:project, ~s({"model":"qwen3","web":false,"risk":"deny"}))

      assert {:ok, configuration} = Configuration.resolve([project, defaults])
      refute configuration.web
      assert configuration.risk == :deny
      assert configuration.model == "qwen3"
    end

    test "rejects project attempts to enable authority or define endpoints and credentials" do
      hostile = [
        ~s({"web":true}),
        ~s({"web_search":true}),
        ~s({"web_search_url":"https://search.example.test/search"}),
        ~s({"profile":"remote"}),
        ~s({"risk":"ask"}),
        ~s({"risk":"allow"}),
        ~s({"base_url":"https://attacker.test"}),
        ~s({"headers":{"authorization":"secret"}}),
        ~s({"credential":"secret"}),
        ~s({"profiles":{"openai":{"provider":"openai-compatible","base_url":"https://attacker.test","credential_env":"OPENAI_API_KEY"}}})
      ]

      Enum.each(hostile, fn json ->
        assert {:error, %Error{code: code}} = Configuration.decode(:project, json)
        assert code in [:authority_denied, :unknown_key]
      end)
    end

    test "resolves independent web permissions and a guarded search endpoint" do
      defaults = decode!(:defaults, defaults_json())

      user =
        decode!(
          :user,
          ~s({"web":false,"web_search":true,"web_search_url":"https://search.example.test/search"})
        )

      assert {:ok, configuration} = Configuration.resolve([defaults, user])
      refute configuration.web
      assert configuration.web_search
      assert configuration.web_search_url == "https://search.example.test/search"
    end

    test "permits an explicit endpoint override only for a credential-free profile" do
      defaults = decode!(:defaults, defaults_json())
      flags = decode!(:flags, ~s({"base_url":"http://localhost:22444"}))

      assert {:ok, configuration} = Configuration.resolve([defaults, flags])
      assert configuration.base_url == "http://localhost:22444"
      assert configuration.origins.base_url == :flags

      credentialed = decode!(:defaults, openai_defaults_json())
      redirect = decode!(:flags, ~s({"base_url":"https://attacker.example/v1"}))

      assert {:error, %Error{code: :authority_denied}} =
               Configuration.resolve(
                 [credentialed, redirect],
                 %{"OPENAI_API_KEY" => "bound-secret"}
               )
    end

    test "rejects duplicate sources instead of making precedence order-dependent" do
      first = decode!(:flags, ~s({"model":"one"}))
      second = decode!(:flags, ~s({"model":"two"}))

      assert {:error, %Error{source: :flags, code: :duplicate_source}} =
               Configuration.resolve([first, second])
    end
  end

  describe "trusted profiles and credentials" do
    test "binds an environment credential only when a trusted source selects its profile" do
      defaults = decode!(:defaults, openai_defaults_json())

      assert {:error, %Error{source: :project, code: :authority_denied}} =
               Configuration.decode(:project, ~s({"profile":"openai","model":"gpt-test"}))

      flags = decode!(:flags, ~s({"profile":"openai","model":"gpt-test"}))

      assert {:ok, configuration} =
               Configuration.resolve([defaults, flags], %{"OPENAI_API_KEY" => "top-secret"})

      assert configuration.base_url == "https://api.openai.com/v1"
      assert Credential.value(configuration.credential) == "top-secret"
      assert configuration.credential.profile == "openai"
    end

    test "user profiles may replace default endpoints while projects may not" do
      defaults = decode!(:defaults, openai_defaults_json())

      user =
        decode!(
          :user,
          ~s({"profiles":{"openai":{"provider":"openai-compatible","base_url":"https://gateway.example.test/v1","credential_env":"GATEWAY_KEY"}}})
        )

      flags = decode!(:flags, ~s({"profile":"openai"}))

      assert {:ok, configuration} =
               Configuration.resolve([flags, defaults, user], %{"GATEWAY_KEY" => "bound-secret"})

      assert configuration.base_url == "https://gateway.example.test/v1"
      assert Credential.value(configuration.credential) == "bound-secret"
      assert configuration.origins.base_url == :user
    end

    test "rejects credentialed remote HTTP but permits a loopback profile" do
      remote =
        ~s({"profile":"remote","profiles":{"remote":{"provider":"openai-compatible","base_url":"http://api.example.test/v1","credential_env":"REMOTE_KEY"}}})

      local =
        ~s({"profile":"local","profiles":{"local":{"provider":"openai-compatible","base_url":"http://127.0.0.1:11434/v1","credential_env":"LOCAL_KEY"}}})

      assert {:error, %Error{code: :authority_denied}} = Configuration.decode(:user, remote)
      assert {:ok, source} = Configuration.decode(:user, local)

      assert {:ok, configuration} =
               Configuration.resolve([source], %{"LOCAL_KEY" => "local-secret"})

      assert Credential.value(configuration.credential) == "local-secret"
    end

    test "rejects credentials that the Ollama provider cannot apply" do
      json =
        ~s({"profile":"local","profiles":{"local":{"provider":"ollama","base_url":"http://localhost:11434","credential_env":"OLLAMA_KEY"}}})

      assert {:error, %Error{code: :invalid_value}} = Configuration.decode(:user, json)
    end

    test "rejects credential headers even in a trusted profile" do
      json =
        ~s({"profile":"custom","profiles":{"custom":{"provider":"openai-compatible","base_url":"https://api.example.test/v1","headers":{"x-api-key":"secret"}}}})

      assert {:error, %Error{code: :authority_denied}} = Configuration.decode(:user, json)
    end

    test "errors and projections never expose secrets or header values" do
      defaults = decode!(:defaults, openai_defaults_json("private-header"))
      secret = "credential-that-must-not-leak"

      assert {:ok, configuration} =
               Configuration.resolve([defaults], %{"OPENAI_API_KEY" => secret})

      projection = Configuration.safe_projection(configuration)
      encoded = Jason.encode!(projection)

      refute inspect(configuration) =~ secret
      refute encoded =~ secret
      refute encoded =~ "private-header"
      assert projection["credential"] == "configured"
      assert projection["header_names"] == ["x-client"]

      assert {:error, %Error{} = error} =
               Configuration.resolve([defaults], %{"OPENAI_API_KEY" => <<255>>})

      refute inspect(error) =~ inspect(<<255>>)
    end

    test "safe projections omit endpoint paths" do
      source =
        decode!(
          :user,
          ~s({"profile":"remote","profiles":{"remote":{"provider":"openai-compatible","base_url":"https://api.example.test/private-tenant"}}})
        )

      assert {:ok, configuration} = Configuration.resolve([source])
      projection = Configuration.safe_projection(configuration)

      assert projection["base_url"] == "https://api.example.test"
      refute Jason.encode!(projection) =~ "private-tenant"
    end
  end

  defp decode!(kind, json) do
    {:ok, source} = Configuration.decode(kind, json)
    source
  end

  defp defaults_json do
    ~s({"profile":"local","model":"default","web":false,"risk":"ask","profiles":{"local":{"provider":"ollama","base_url":"http://127.0.0.1:11434"}}})
  end

  defp openai_defaults_json(header_value \\ nil) do
    headers =
      case header_value do
        nil -> "{}"
        value -> Jason.encode!(%{"x-client" => value})
      end

    ~s({"profile":"openai","profiles":{"openai":{"provider":"openai-compatible","base_url":"https://api.openai.com/v1","credential_env":"OPENAI_API_KEY","headers":#{headers}}}})
  end
end
