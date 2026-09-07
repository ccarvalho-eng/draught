defmodule Draught.CLI.Task.ProviderTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Configuration
  alias Draught.CLI.Configuration.Credential
  alias Draught.CLI.Task.Provider.Local
  alias Draught.Provider.Ollama.Discovery.HTTP.Response

  defmodule DiscoveryHTTP do
    @behaviour Draught.Provider.Ollama.Discovery.HTTP

    @impl Draught.Provider.Ollama.Discovery.HTTP
    def request(_method, _url, _body, _configuration) do
      receive do
        {:discovery_response, response} -> response
      end
    end
  end

  defmodule ProviderTransport do
    @behaviour Draught.Provider.OpenAI.Transport

    @impl Draught.Provider.OpenAI.Transport
    def complete(_request, _configuration) do
      {:error, :not_used}
    end

    @impl Draught.Provider.OpenAI.Transport
    def stream(_request, _configuration, state, _reducer) do
      {:error, :not_used, state}
    end
  end

  test "returns the exact explicit Ollama model selected after capability checks" do
    queue_model(["completion", "tools"])

    result =
      :ollama
      |> configuration("qwen3")
      |> Local.build(dependencies())

    assert {:ok, selection} = result
    assert selection.model == "qwen3"
    assert selection.capabilities.chat
    assert selection.capabilities.tool_calls
  end

  test "returns the exact automatically selected Ollama model" do
    queue_list(["qwen3"])
    queue_model(["completion", "tools"])

    result =
      :ollama
      |> configuration(nil)
      |> Local.build(dependencies())

    assert {:ok, selection} = result
    assert selection.model == "qwen3"
  end

  test "builds OpenAI-compatible providers without exposing credentials" do
    assert {:ok, credential} = Credential.new("remote", "secret-token")

    configuration =
      configuration(:openai_compatible, "deepseek-chat", credential: credential)

    assert {:ok, selection} = Local.build(configuration, dependencies())
    assert selection.model == "deepseek-chat"
    refute inspect(selection.adapter) =~ "secret-token"
  end

  test "requires an explicit model for OpenAI-compatible providers" do
    result =
      :openai_compatible
      |> configuration(nil)
      |> Local.build(dependencies())

    assert {:error, error} = result
    violation = hd(error.violations)
    assert violation.path == [:model]
  end

  defp configuration(provider, model, options \\ []) do
    %Configuration{
      profile: "test",
      provider: provider,
      base_url: base_url(provider),
      model: model,
      credential: Keyword.get(options, :credential),
      headers: %{},
      web: false,
      risk: :ask,
      origins: %{}
    }
  end

  defp base_url(:ollama) do
    "http://localhost:11434"
  end

  defp base_url(:openai_compatible) do
    "https://api.example.test/v1"
  end

  defp dependencies do
    [
      discovery_http: DiscoveryHTTP,
      provider_transport: {ProviderTransport, nil}
    ]
  end

  defp queue_list(models) do
    body = Jason.encode!(%{"models" => Enum.map(models, &%{"name" => &1})})
    send(self(), {:discovery_response, {:ok, %Response{status: 200, body: body}}})
  end

  defp queue_model(capabilities) do
    body = Jason.encode!(%{"capabilities" => capabilities, "model_info" => %{}})
    send(self(), {:discovery_response, {:ok, %Response{status: 200, body: body}}})
  end
end
