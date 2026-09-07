defmodule Draught.CLI.Configuration.LoaderTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Command.Invocation
  alias Draught.CLI.Configuration
  alias Draught.CLI.Configuration.Error
  alias Draught.CLI.Configuration.Loader

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
    def write(_stream, _content, _configuration) do
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

  test "loads optional files and resolves flags over environment, project, user, and defaults" do
    cwd = "/workspace"

    files = %{
      "/user/draught/config.json" =>
        {:ok,
         ~s({"profile":"lab","model":"user","profiles":{"lab":{"provider":"ollama","base_url":"http://localhost:11434"}}})},
      "/workspace/.draught/config.json" => {:ok, ~s({"model":"project"})}
    }

    environment = %{
      "XDG_CONFIG_HOME" => "/user",
      "DRAUGHT_MODEL" => "environment"
    }

    invocation = %Invocation{command: :doctor, model: "flag"}
    system = {SystemAdapter, %{cwd: cwd, environment: environment, files: files}}

    assert {:ok, %Configuration{} = configuration, ^cwd} = Loader.load(invocation, system)
    assert configuration.profile == "lab"
    assert configuration.model == "flag"
    assert configuration.origins.model == :flags
  end

  test "uses the credential-free loopback Ollama default without configuration files" do
    invocation = %Invocation{command: :doctor}
    system = {SystemAdapter, %{cwd: "/workspace", environment: %{}, files: %{}}}

    assert {:ok, configuration, "/workspace"} = Loader.load(invocation, system)
    assert configuration.profile == "ollama"
    assert configuration.provider == :ollama
    assert configuration.base_url == "http://localhost:11434"
    assert configuration.model == nil
    refute configuration.web
  end

  test "rejects project authority expansion before any provider operation" do
    files = %{
      "/workspace/.draught/config.json" => {:ok, ~s({"web":true})}
    }

    invocation = %Invocation{command: :doctor}
    system = {SystemAdapter, %{cwd: "/workspace", environment: %{}, files: files}}

    assert {:error, %Error{source: :project, code: :authority_denied}} =
             Loader.load(invocation, system)
  end

  test "rejects malformed environment settings without retaining their values" do
    secret = "unsafe-value-#{<<0x202E::utf8>>}"
    environment = %{"DRAUGHT_MODEL" => secret}
    invocation = %Invocation{command: :doctor}
    system = {SystemAdapter, %{cwd: "/workspace", environment: environment, files: %{}}}

    assert {:error, %Error{} = error} = Loader.load(invocation, system)
    refute inspect(error) =~ secret
  end
end
