defmodule Draught.CLITest do
  use ExUnit.Case, async: true

  alias Draught.CLI
  alias Draught.CLI.Dependencies
  alias Draught.CLI.Task.Provider.Selection
  alias Draught.Conversation
  alias Draught.Conversation.Message.Tool
  alias Draught.Error.Normalized
  alias Draught.Provider.Capabilities
  alias Draught.Provider.Ollama.Discovery.HTTP.Failure
  alias Draught.Provider.Response
  alias Draught.Session
  alias Draught.Tool.Call

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

  defmodule StaticProvider do
    @behaviour Draught.Provider

    @impl Draught.Provider
    def capabilities(_configuration) do
      Capabilities.new(chat: true, tool_calls: true)
    end

    @impl Draught.Provider
    def complete(_request, {:error, error}) do
      {:error, error}
    end

    def complete(_request, response) do
      {:ok, response}
    end

    @impl Draught.Provider
    def stream(_request, _configuration, _sink) do
      {:error, :not_used}
    end
  end

  defmodule ProviderFactory do
    @behaviour Draught.CLI.Task.Provider.Adapter

    @impl Draught.CLI.Task.Provider.Adapter
    def build(_configuration, response) do
      Selection.new({StaticProvider, response}, "free-model")
    end
  end

  defmodule FailingProviderFactory do
    @behaviour Draught.CLI.Task.Provider.Adapter

    @impl Draught.CLI.Task.Provider.Adapter
    def build(_configuration, error) do
      {:error, error}
    end
  end

  defmodule InvalidProviderFactory do
    @behaviour Draught.CLI.Task.Provider.Adapter

    @impl Draught.CLI.Task.Provider.Adapter
    def build(_configuration, _dependency) do
      {:ok, :invalid_selection}
    end
  end

  defmodule BlockingProvider do
    @behaviour Draught.Provider

    @impl Draught.Provider
    def capabilities(_owner) do
      Capabilities.new(chat: true, tool_calls: true)
    end

    @impl Draught.Provider
    def complete(_request, owner) do
      send(owner, {:blocking_provider_started, self()})

      receive do
        :complete -> {:error, :unexpected_completion}
      after
        5_000 -> {:error, :blocking_provider_timeout}
      end
    end

    @impl Draught.Provider
    def stream(_request, _owner, _sink) do
      {:error, :not_used}
    end
  end

  defmodule BlockingProviderFactory do
    @behaviour Draught.CLI.Task.Provider.Adapter

    @impl Draught.CLI.Task.Provider.Adapter
    def build(_configuration, owner) do
      Selection.new({BlockingProvider, owner}, "free-model")
    end
  end

  defmodule ScriptedProvider do
    @behaviour Draught.Provider

    @impl Draught.Provider
    def capabilities(_owner) do
      Capabilities.new(chat: true, tool_calls: true)
    end

    @impl Draught.Provider
    def complete(request, owner) do
      send(owner, {:scripted_provider_request, self(), request})

      receive do
        {:scripted_provider_result, result} -> result
      end
    end

    @impl Draught.Provider
    def stream(_request, _owner, _sink) do
      {:error, :not_used}
    end
  end

  defmodule ScriptedProviderFactory do
    @behaviour Draught.CLI.Task.Provider.Adapter

    @impl Draught.CLI.Task.Provider.Adapter
    def build(_configuration, owner) do
      Selection.new({ScriptedProvider, owner}, "free-model")
    end
  end

  defmodule CompletionTransport do
    @behaviour Draught.Provider.OpenAI.Transport

    alias Draught.Provider.OpenAI.Transport.Response

    @impl Draught.Provider.OpenAI.Transport
    def complete(request, {owner, body}) do
      send(owner, {:completion_request, request})
      {:ok, %Response{status: 200, body: body}}
    end

    @impl Draught.Provider.OpenAI.Transport
    def stream(_request, _configuration, state, _reducer) do
      {:error, :not_used, state}
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

  test "requires a prompt for named session execution" do
    dependencies = dependencies()

    assert CLI.run(["--resume", "review"], dependencies) == 5
    assert_receive {:cli_output, :stderr, text}
    assert text =~ "task prompt is required"

    assert CLI.run(["--session", "review", "--output", "jsonl"], dependencies) == 5
    assert_receive {:cli_output, :stderr, jsonl}
    assert Jason.decode!(jsonl)["code"] == "prompt_required"
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

  test "runs a credential-free one-shot task through the session boundary" do
    assert {:ok, assistant} = Conversation.assistant(content: "Inspection complete")
    assert {:ok, response} = Response.new(message: assistant, finish_reason: :stop)

    assert CLI.run(["inspect this project"], dependencies(provider_response: response)) == 0
    assert_receive {:cli_output, :stdout, "Inspection complete\n"}
  end

  test "maps supervised session cancellation to the CLI exit boundary" do
    identifier = "cancel-smoke-#{System.unique_integer([:positive, :monotonic])}"

    dependencies =
      dependencies(
        provider_factory: {BlockingProviderFactory, self()},
        identifier: fn -> {:ok, identifier} end
      )

    task = Task.async(fn -> CLI.run(["inspect this project"], dependencies) end)

    assert_receive {:blocking_provider_started, provider}
    provider_monitor = Process.monitor(provider)
    assert :ok = Session.cancel(identifier)
    assert Task.await(task) == 130
    assert_receive {:DOWN, ^provider_monitor, :process, ^provider, :killed}
    assert_receive {:cli_output, :stderr, output}
    assert output =~ "session_cancelled"
  end

  test "denies an effectful tool through the CLI entry boundary" do
    dependencies =
      dependencies(
        environment: %{"DRAUGHT_RISK" => "deny"},
        provider_factory: {ScriptedProviderFactory, self()}
      )

    task = Task.async(fn -> CLI.run(["update sample.txt"], dependencies) end)

    assert_receive {:scripted_provider_request, first_provider, _first_request}
    call = replace_call()
    send(first_provider, {:scripted_provider_result, {:ok, tool_response(call)}})

    assert_receive {:scripted_provider_request, second_provider, second_request}

    assert [%Tool{result: %{error: %{code: "tool_risk_denied"}}} | _messages] =
             Enum.reverse(second_request.messages)

    final = response("The edit was denied")
    send(second_provider, {:scripted_provider_result, {:ok, final}})

    assert Task.await(task) == 0
    assert_receive {:cli_output, :stdout, "The edit was denied\n"}
  end

  @tag :tmp_dir
  test "edits and verifies through the credential-free CLI entry boundary", %{
    tmp_dir: workspace
  } do
    path = Path.join(workspace, "sample.txt")
    File.write!(path, "before")

    dependencies =
      dependencies(
        cwd: workspace,
        environment: %{"DRAUGHT_RISK" => "allow"},
        provider_factory: {ScriptedProviderFactory, self()}
      )

    task = Task.async(fn -> CLI.run(["update and verify sample.txt"], dependencies) end)

    assert_receive {:scripted_provider_request, first_provider, _first_request}
    send(first_provider, {:scripted_provider_result, {:ok, tool_response(replace_call())}})

    assert_receive {:scripted_provider_request, second_provider, second_request}

    assert [%Tool{result: %{status: :success}} | _messages] =
             Enum.reverse(second_request.messages)

    assert File.read!(path) == "after"
    send(second_provider, {:scripted_provider_result, {:ok, tool_response(read_call())}})

    assert_receive {:scripted_provider_request, third_provider, third_request}

    assert [%Tool{result: %{status: :success, content: "after"}} | _messages] =
             Enum.reverse(third_request.messages)

    send(third_provider, {:scripted_provider_result, {:ok, response("Updated and verified")}})

    assert Task.await(task) == 0
    assert_receive {:cli_output, :stdout, "Updated and verified\n"}
  end

  test "auto-selects one compatible Ollama model for a complete CLI task" do
    queue_list(["qwen3"])
    queue_model(["completion", "tools"])

    body =
      Jason.encode!(%{
        "choices" => [
          %{
            "finish_reason" => "stop",
            "index" => 0,
            "message" => %{"content" => "Local task complete", "role" => "assistant"}
          }
        ]
      })

    provider =
      {Draught.CLI.Task.Provider.Local,
       [
         discovery_http: DiscoveryHTTP,
         provider_transport: {CompletionTransport, {self(), body}}
       ]}

    assert CLI.run(["inspect this project"], dependencies(provider_factory: provider)) == 0
    assert_receive {:completion_request, request}
    assert request.body["model"] == "qwen3"
    assert_receive {:cli_output, :stdout, "Local task complete\n"}
  end

  test "renders one-shot task results as JSONL" do
    assert {:ok, assistant} = Conversation.assistant(content: "done")
    assert {:ok, response} = Response.new(message: assistant, finish_reason: :stop)

    assert CLI.run(
             ["inspect", "--output", "jsonl"],
             dependencies(provider_response: response)
           ) == 0

    assert_receive {:cli_output, :stdout, output}

    decoded =
      output
      |> String.trim()
      |> Jason.decode!()

    assert %{"type" => "task", "status" => "ok", "content" => "done"} = decoded
  end

  @tag :tmp_dir
  test "creates and resumes named tasks while keeping enabled web unavailable", %{
    tmp_dir: tmp_dir
  } do
    workspace = Path.join(tmp_dir, "workspace")
    environment = %{"XDG_STATE_HOME" => Path.join(tmp_dir, "state")}
    File.mkdir_p!(workspace)
    dependencies = dependencies(cwd: workspace, environment: environment)

    assert CLI.run(["inspect", "--session", "named"], dependencies) == 0
    assert_receive {:cli_output, :stdout, "unused\n"}

    assert CLI.run(["continue", "--resume", "named"], dependencies) == 0
    assert_receive {:cli_output, :stdout, "unused\n"}

    assert CLI.run(["inspect", "--session", "named"], dependencies) == 5
    assert_receive {:cli_output, :stderr, session_output}
    assert session_output =~ "already exists"

    assert CLI.run(["inspect", "--web"], dependencies()) == 4
    assert_receive {:cli_output, :stderr, web_output}
    assert web_output =~ "Web execution"
  end

  test "uses stable provider, execution, and session exits" do
    {:ok, unavailable} =
      Normalized.new(
        :transport,
        "provider_unavailable",
        "Provider is unavailable",
        retryable: true
      )

    assert CLI.run(
             ["inspect"],
             dependencies(provider_factory: {FailingProviderFactory, unavailable})
           ) == 3

    assert_receive {:cli_output, :stderr, provider_output}
    assert provider_output =~ "provider_unavailable"

    assert CLI.run(
             ["inspect"],
             dependencies(provider_response: {:error, unavailable})
           ) == 4

    assert_receive {:cli_output, :stderr, execution_output}
    assert execution_output =~ "provider_unavailable"

    assert CLI.run(
             ["inspect"],
             dependencies(identifier: fn -> {:error, :unavailable} end)
           ) == 5

    assert_receive {:cli_output, :stderr, session_output}
    assert session_output =~ "invalid_task_identifier"
  end

  test "identifies provider, execution, and session failures in JSONL" do
    {:ok, unavailable} =
      Normalized.new(
        :transport,
        "provider_unavailable",
        "Provider is unavailable",
        retryable: true
      )

    assert CLI.run(
             ["inspect", "--output", "jsonl"],
             dependencies(provider_factory: {FailingProviderFactory, unavailable})
           ) == 3

    assert_receive {:cli_output, :stderr, provider_output}
    assert Jason.decode!(provider_output)["category"] == "provider"

    assert CLI.run(
             ["inspect", "--output", "jsonl"],
             dependencies(provider_response: {:error, unavailable})
           ) == 4

    assert_receive {:cli_output, :stderr, execution_output}
    assert Jason.decode!(execution_output)["category"] == "execution"

    assert CLI.run(
             ["inspect", "--output", "jsonl"],
             dependencies(identifier: fn -> {:error, :unavailable} end)
           ) == 5

    assert_receive {:cli_output, :stderr, session_output}
    assert Jason.decode!(session_output)["category"] == "session"
  end

  test "normalizes an invalid provider-factory result" do
    dependencies = dependencies(provider_factory: {InvalidProviderFactory, nil})

    assert CLI.run(["inspect"], dependencies) == 3
    assert_receive {:cli_output, :stderr, output}
    assert output =~ "invalid_provider_selection"
  end

  test "keeps session validation failures in the session category" do
    dependencies = dependencies(identifier: fn -> {:ok, "../invalid"} end)

    assert CLI.run(["inspect", "--output", "jsonl"], dependencies) == 5
    assert_receive {:cli_output, :stderr, output}

    assert %{"category" => "session", "code" => "invalid_setup"} =
             Jason.decode!(output)
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
    provider_response =
      Keyword.get_lazy(options, :provider_response, fn ->
        {:ok, assistant} = Conversation.assistant(content: "unused")
        {:ok, response} = Response.new(message: assistant, finish_reason: :stop)
        response
      end)

    provider_factory =
      Keyword.get(options, :provider_factory, {ProviderFactory, provider_response})

    default_identifier = "cli-one-shot-#{System.unique_integer([:positive, :monotonic])}"
    identifier = Keyword.get(options, :identifier, fn -> {:ok, default_identifier} end)

    system =
      {SystemAdapter,
       %{
         owner: self(),
         cwd: Keyword.get(options, :cwd, "/workspace"),
         environment: Keyword.get(options, :environment, %{}),
         files: Keyword.get(options, :files, %{})
       }}

    {:ok, dependencies} =
      Dependencies.new(
        system: system,
        discovery_http: DiscoveryHTTP,
        task: [
          provider: provider_factory,
          identifier: identifier
        ]
      )

    dependencies
  end

  defp queue(response) do
    send(self(), {:discovery_response, response})
  end

  defp queue_list(models) do
    body = Jason.encode!(%{"models" => Enum.map(models, &%{"name" => &1})})

    queue({
      :ok,
      %Draught.Provider.Ollama.Discovery.HTTP.Response{status: 200, body: body}
    })
  end

  defp queue_model(capabilities) do
    body = Jason.encode!(%{"capabilities" => capabilities, "model_info" => %{}})

    queue({
      :ok,
      %Draught.Provider.Ollama.Discovery.HTTP.Response{status: 200, body: body}
    })
  end

  defp replace_call do
    {:ok, call} =
      Call.new(
        id: "replace-1",
        name: "replace_in_file",
        arguments: %{
          "expected" => "before",
          "path" => "sample.txt",
          "replacement" => "after"
        }
      )

    call
  end

  defp read_call do
    {:ok, call} =
      Call.new(
        id: "read-1",
        name: "read_file",
        arguments: %{"path" => "sample.txt"}
      )

    call
  end

  defp tool_response(call) do
    {:ok, assistant} = Conversation.assistant(tool_calls: [call])
    {:ok, response} = Response.new(message: assistant, finish_reason: :tool_calls)
    response
  end

  defp response(content) do
    {:ok, assistant} = Conversation.assistant(content: content)
    {:ok, response} = Response.new(message: assistant, finish_reason: :stop)
    response
  end
end
