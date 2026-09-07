defmodule Draught.CLI.Session.BindingTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Configuration
  alias Draught.CLI.Session.Binding
  alias Draught.CLI.Session.Binding.Local
  alias Draught.CLI.Session.Store.Paths
  alias Draught.CLI.Task.Preparation
  alias Draught.CLI.Task.Provider.Selection
  alias Draught.Provider.Fake

  @moduletag :tmp_dir

  test "stores exact provider identity without raw connection values", %{tmp_dir: tmp_dir} do
    configuration = configuration("free-model")
    assert {:ok, provider} = Fake.new()
    assert {:ok, selection} = Selection.new({Fake, provider}, "free-model")
    assert {:ok, preparation} = Preparation.new("Inspect", selection, tmp_dir)
    binding = Binding.new(configuration, preparation)

    assert {:ok, encoded} = Binding.encode(binding)
    refute encoded =~ configuration.base_url
    refute encoded =~ "private-header"
    assert {:ok, decoded} = Binding.decode(encoded)
    assert decoded == binding
    assert decoded.model == "free-model"
    assert decoded.adapter == "Elixir.Draught.Provider.Fake"
  end

  test "forces the recorded model and rejects connection or explicit model drift", %{
    tmp_dir: tmp_dir
  } do
    configuration = configuration("free-model")
    assert {:ok, provider} = Fake.new()
    assert {:ok, selection} = Selection.new({Fake, provider}, "free-model")
    assert {:ok, preparation} = Preparation.new("Inspect", selection, tmp_dir)
    binding = Binding.new(configuration, preparation)

    assert {:ok, bound} = Binding.bind_configuration(binding, %{configuration | model: nil})
    assert bound.model == "free-model"

    assert {:error, %{code: "session_binding_mismatch"}} =
             Binding.bind_configuration(binding, %{configuration | model: "other"})

    assert {:error, %{code: "session_binding_mismatch"}} =
             Binding.bind_configuration(binding, %{
               configuration
               | base_url: "http://localhost:11435"
             })
  end

  test "persists an owner-only binding and rejects unsafe replacements", %{tmp_dir: tmp_dir} do
    workspace = Path.join(tmp_dir, "workspace")
    state = Path.join(tmp_dir, "state")
    File.mkdir_p!(workspace)
    assert {:ok, paths} = Paths.new(workspace, "review", %{"XDG_STATE_HOME" => state})
    File.mkdir_p!(paths.session)
    File.chmod!(paths.session, 0o700)
    binding = sample_binding()

    assert :ok = Local.create(paths, binding)
    assert {:ok, ^binding} = Local.read(paths)
    assert {:ok, %File.Stat{mode: mode}} = File.lstat(paths.binding)
    assert Bitwise.band(mode, 0o777) == 0o600

    File.rm!(paths.binding)
    target = Path.join(tmp_dir, "target")
    File.write!(target, "{}")
    File.ln_s!(target, paths.binding)
    assert {:error, %{code: "session_binding_invalid"}} = Local.read(paths)
  end

  test "never replaces an existing binding", %{tmp_dir: tmp_dir} do
    workspace = Path.join(tmp_dir, "workspace")
    state = Path.join(tmp_dir, "state")
    File.mkdir_p!(workspace)
    assert {:ok, paths} = Paths.new(workspace, "review", %{"XDG_STATE_HOME" => state})
    File.mkdir_p!(paths.session)
    File.chmod!(paths.session, 0o700)
    original = sample_binding()
    replacement = %{original | model: "other-model"}

    assert :ok = Local.create(paths, original)
    assert {:error, %{code: "session_storage_unavailable"}} = Local.create(paths, replacement)
    assert {:ok, ^original} = Local.read(paths)
  end

  test "rejects unknown and oversized binding representations", %{tmp_dir: tmp_dir} do
    unknown = Jason.encode!(%{"schema" => "unknown"})

    assert {:error, %{code: "session_binding_invalid"}} =
             Binding.decode(unknown)

    workspace = Path.join(tmp_dir, "workspace")
    state_home = Path.join(tmp_dir, "state")
    File.mkdir_p!(workspace)

    assert {:ok, paths} =
             Paths.new(workspace, "review", %{"XDG_STATE_HOME" => state_home})

    File.mkdir_p!(paths.session)
    File.write!(paths.binding, String.duplicate("x", 4_097))
    File.chmod!(paths.binding, 0o600)
    assert {:error, %{code: "session_binding_invalid"}} = Local.read(paths)
  end

  defp sample_binding do
    %Binding{
      adapter: "Elixir.Draught.Provider.Fake",
      connection: String.duplicate("a", 64),
      model: "free-model",
      profile: "test",
      provider: "ollama"
    }
  end

  defp configuration(model) do
    %Configuration{
      profile: "test",
      provider: :ollama,
      base_url: "http://localhost:11434",
      model: model,
      credential: nil,
      headers: %{"x-private" => "private-header"},
      web: false,
      risk: :deny,
      origins: %{}
    }
  end
end
