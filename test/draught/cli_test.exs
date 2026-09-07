defmodule Draught.CLITest do
  use ExUnit.Case, async: true

  alias Draught.CLI
  alias Draught.CLI.Dependencies
  alias Draught.Provider.Ollama.Discovery.HTTP.Failure
  alias Draught.Provider.Ollama.Discovery.HTTP.Response

  defmodule SystemAdapter do
    @behaviour Draught.CLI.System.Adapter

    @impl Draught.CLI.System.Adapter
    def cwd(configuration) do
      {:ok, configuration.cwd}
    end

    @impl Draught.CLI.System.Adapter
    def environment(configuration) do
      configuration.environment
    end

    @impl Draught.CLI.System.Adapter
    def read_file(path, _maximum_bytes, configuration) do
      Map.get(configuration.files, path, :missing)
    end

    @impl Draught.CLI.System.Adapter
    def workspace(_path, _configuration) do
      :ok
    end

    @impl Draught.CLI.System.Adapter
    def write(stream, content, configuration) do
      send(configuration.owner, {:cli_output, stream, IO.iodata_to_binary(content)})
      :ok
    end

    @impl Draught.CLI.System.Adapter
    def tty?(_stream, _configuration) do
      false
    end

    @impl Draught.CLI.System.Adapter
    def columns(_configuration) do
      {:ok, 80}
    end
  end

  defmodule DiscoveryHTTP do
    @behaviour Draught.Provider.Ollama.Discovery.HTTP

    @impl Draught.Provider.Ollama.Discovery.HTTP
    def request(_method, _url, _body, _configuration) do
      receive do
        {:discovery_response, response} -> response
      end
    end
  end

  test "renders help and version without loading configuration" do
    dependencies = dependencies()

    assert CLI.run(["--help"], dependencies) == 0
    assert_receive {:cli_output, :stdout, help}
    assert help =~ "Usage"
    assert help =~ ~s(draught "fix the tests")

    assert CLI.run(["--version"], dependencies) == 0
    assert_receive {:cli_output, :stdout, version}
    assert version == "draught #{Application.spec(:draught, :vsn)}\n"
  end

  test "renders help and version as JSONL when requested" do
    dependencies = dependencies()

    assert CLI.run(["--help", "--output", "jsonl"], dependencies) == 0
    assert_receive {:cli_output, :stdout, help}
    assert Jason.decode!(help)["type"] == "help"

    assert CLI.run(["--version", "--output", "jsonl"], dependencies) == 0
    assert_receive {:cli_output, :stdout, version}
    assert Jason.decode!(version)["type"] == "version"
  end

  test "doctor reports one compatible local model without issuing a completion" do
    queue_list(["qwen3"])
    queue_model(["completion", "tools"])

    assert CLI.run(["doctor"], dependencies()) == 0
    assert_receive {:cli_output, :stdout, output}
    assert output =~ "Workspace: ok"
    assert output =~ "Ollama: ok"
    assert output =~ "qwen3"
  end

  test "doctor inspects only an explicitly selected model" do
    queue_model(["completion", "tools"])

    assert CLI.run(["doctor", "--model", "qwen3"], dependencies()) == 0
    assert_receive {:cli_output, :stdout, output}
    assert output =~ "selected model is compatible"
  end

  test "doctor returns a stable provider exit and actionable unavailable message" do
    queue({:error, Failure.new(:unavailable)})

    assert CLI.run(["doctor"], dependencies()) == 3
    assert_receive {:cli_output, :stdout, output}
    assert output =~ "Ollama: error"
    assert output =~ "Start Ollama"
  end

  test "doctor explains models that lack agent capabilities" do
    queue_list(["chat-only"])
    queue_model(["completion"])

    assert CLI.run(["doctor"], dependencies()) == 3
    assert_receive {:cli_output, :stdout, output}
    assert output =~ "required agent capabilities"
    assert output =~ "Incompatible models: chat-only"
  end

  test "doctor requires model selection when multiple compatible models are installed" do
    queue_list(["qwen3", "devstral"])
    queue_model(["completion", "tools"])
    queue_model(["completion", "tools"])

    assert CLI.run(["doctor"], dependencies()) == 3
    assert_receive {:cli_output, :stdout, output}
    assert output =~ "2 compatible models require an explicit selection"
    assert output =~ "--model"
  end

  test "doctor does not claim unchecked OpenAI-compatible providers are healthy" do
    user_configuration =
      ~s({"profiles":{"remote":{"provider":"openai-compatible","base_url":"https://api.example.test/v1"}}})

    files = %{"/user/draught/config.json" => {:ok, user_configuration}}
    environment = %{"XDG_CONFIG_HOME" => "/user"}

    status =
      CLI.run(
        ["doctor", "--provider", "remote", "--model", "model"],
        dependencies(files: files, environment: environment)
      )

    assert status == 3
    assert_receive {:cli_output, :stdout, output}
    assert output =~ "were not checked"
  end

  test "JSONL doctor output is one parseable unstyled record" do
    queue_list([])

    assert CLI.run(["doctor", "--output", "jsonl"], dependencies()) == 3
    assert_receive {:cli_output, :stdout, output}
    assert [line] = String.split(output, "\n", trim: true)
    decoded = Jason.decode!(line)
    assert decoded["schema"] == "draught.cli/v1"
    assert decoded["type"] == "doctor"
    refute output =~ <<27>>
  end

  test "usage errors write only a bounded safe error to stderr" do
    assert CLI.run(["--unknown"], dependencies()) == 2
    assert_receive {:cli_output, :stderr, output}
    assert output =~ "Unknown command option"
    refute_receive {:cli_output, :stdout, _content}
  end

  test "agent commands fail explicitly until the execution slice is connected" do
    assert CLI.run(["inspect this project"], dependencies()) == 4
    assert_receive {:cli_output, :stderr, output}
    assert output =~ "Agent execution is not available"
  end

  test "configuration failures honor JSONL output without reflecting rejected values" do
    secret = "invalid-value"
    environment = %{"DRAUGHT_WEB" => secret}

    assert CLI.run(
             ["doctor", "--output", "jsonl"],
             dependencies(environment: environment)
           ) == 2

    assert_receive {:cli_output, :stderr, output}

    assert {:ok, record} =
             output
             |> String.trim()
             |> Jason.decode()

    assert record["category"] == "configuration"
    refute output =~ secret
  end

  test "project configuration cannot activate a credential-free remote profile" do
    user =
      ~s({"profiles":{"remote":{"provider":"ollama","base_url":"https://internal.example.test"}}})

    files = %{
      "/user/draught/config.json" => {:ok, user},
      "/workspace/.draught/config.json" => {:ok, ~s({"profile":"remote"})}
    }

    environment = %{"XDG_CONFIG_HOME" => "/user"}

    assert CLI.run(
             ["doctor"],
             dependencies(files: files, environment: environment)
           ) == 2

    assert_receive {:cli_output, :stderr, output}
    assert output =~ "project settings cannot select a provider profile"
  end

  defp dependencies(options \\ []) do
    system =
      {SystemAdapter,
       %{
         owner: self(),
         cwd: "/workspace",
         environment: Keyword.get(options, :environment, %{}),
         files: Keyword.get(options, :files, %{})
       }}

    {:ok, dependencies} = Dependencies.new(system: system, discovery_http: DiscoveryHTTP)
    dependencies
  end

  defp queue(response) do
    send(self(), {:discovery_response, response})
  end

  defp queue_list(models) do
    body = Jason.encode!(%{"models" => Enum.map(models, &%{"name" => &1})})
    queue({:ok, %Response{status: 200, body: body}})
  end

  defp queue_model(capabilities) do
    body = Jason.encode!(%{"capabilities" => capabilities, "model_info" => %{}})
    queue({:ok, %Response{status: 200, body: body}})
  end
end
