defmodule Draught.CLI.Session.CatalogTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Session.Binding
  alias Draught.CLI.Session.Catalog
  alias Draught.CLI.Session.Catalog.Local
  alias Draught.CLI.Session.Catalog.Scanner.Artifact
  alias Draught.CLI.Session.Store
  alias Draught.CLI.Session.Store.Scope
  alias Draught.CLI.UI

  @moduletag :tmp_dir

  test "lists legacy sessions without creating state or replaying journals", %{tmp_dir: root} do
    {workspace, environment} = context(root)
    assert {:ok, []} = Catalog.list(adapter(), workspace, environment)
    assert {:ok, scope} = Scope.new(workspace, environment)
    refute File.exists?(scope.root)

    create_session(workspace, environment, "session-01", "qwen3")
    assert {:ok, [entry]} = Catalog.list(adapter(), workspace, environment)
    assert entry.id == "session-01"
    assert entry.label == "session-01"
    assert entry.archive == :active
    assert entry.provider == "ollama"
    assert entry.model == "qwen3"
  end

  test "renames, archives, rejects resume, and restores under the session lease", %{tmp_dir: root} do
    {workspace, environment} = context(root)
    create_session(workspace, environment, "session-01", "qwen3")

    assert {:ok, renamed} =
             Catalog.rename(adapter(), workspace, "session-01", "Review", environment)

    assert renamed.id == "session-01"
    assert renamed.label == "Review"

    assert {:ok, archived} = Catalog.archive(adapter(), workspace, "session-01", environment)
    assert archived.archive == {:archived, ~U[2026-09-07 12:00:00Z]}

    assert {:error, error} = Store.open(:resume, workspace, "session-01", environment)
    assert error.code == "session_archived"

    assert {:ok, restored} = Catalog.restore(adapter(), workspace, "session-01", environment)
    assert restored.archive == :active
    assert {:ok, store} = Store.open(:resume, workspace, "session-01", environment)
    assert :ok = Store.close(store)
  end

  test "marks corrupt records unavailable without projecting their contents", %{tmp_dir: root} do
    {workspace, environment} = context(root)
    paths = create_session(workspace, environment, "session-01", "qwen3")
    File.write!(paths.metadata, ~s({"label":"\u001b[31msecret"}))
    File.chmod!(paths.metadata, 0o600)

    assert {:ok, [entry]} = Catalog.list(adapter(), workspace, environment)
    assert entry.availability == :unavailable
    assert entry.label == "session-01"
    assert entry.provider == nil
  end

  test "does not project multiline provider binding values into catalog output", %{tmp_dir: root} do
    {workspace, environment} = context(root)
    paths = create_session(workspace, environment, "session-01", "qwen3")
    unsafe = %{session_binding("qwen3") | model: "qwen3\n* fake\trow"}
    assert {:ok, encoded} = Binding.encode(unsafe)
    File.write!(paths.binding, encoded)
    File.chmod!(paths.binding, 0o600)

    assert {:ok, [entry]} = Catalog.list(adapter(), workspace, environment)
    assert entry.availability == :unavailable
    rendered = UI.sessions([entry], "other", :all)
    output = IO.iodata_to_binary(rendered)
    refute output =~ "fake"
    refute output =~ "\t"
  end

  test "rejects unvalidated directory entries and bounds catalog scans", %{tmp_dir: root} do
    {workspace, environment} = context(root)
    assert {:ok, scope} = Scope.new(workspace, environment)
    File.mkdir_p!(scope.sessions)
    secure_scope(scope)
    invalid_path = Path.join(scope.sessions, "invalid name")
    File.mkdir!(invalid_path)

    assert {:error, unsafe} = Catalog.list(adapter(), workspace, environment)
    assert unsafe.code == "session_storage_unsafe"

    File.rmdir!(invalid_path)

    Enum.each(0..256, fn index ->
      File.mkdir!(Path.join(scope.sessions, "session-#{index}"))
    end)

    assert {:error, too_large} = Catalog.list(adapter(), workspace, environment)
    assert too_large.code == "session_catalog_too_large"
  end

  test "rejects invalid UTF-8 directory entries without running a Unicode regex", %{
    tmp_dir: root
  } do
    assert {:error, error} = Artifact.validate(root, <<255>>)
    assert error.code == "session_storage_unsafe"
  end

  test "rejects an intermediate symlink in the application-owned catalog path", %{
    tmp_dir: root
  } do
    {workspace, environment} = context(root)
    assert {:ok, scope} = Scope.new(workspace, environment)
    workspaces = Path.join(scope.root, "workspaces")
    File.mkdir_p!(workspaces)
    File.chmod!(scope.root, 0o700)
    File.chmod!(workspaces, 0o700)

    redirected = Path.join(root, "redirected-workspace")
    File.mkdir!(redirected)
    File.ln_s!(redirected, scope.workspace)

    assert {:error, error} = Catalog.list(adapter(), workspace, environment)
    assert error.code == "session_storage_unsafe"
  end

  test "ignores bounded owner-only artifacts left by interrupted atomic writes", %{
    tmp_dir: root
  } do
    {workspace, environment} = context(root)
    create_session(workspace, environment, "session-01", "qwen3")
    assert {:ok, scope} = Scope.new(workspace, environment)
    artifact = Path.join(scope.sessions, ".binding-AAAAAAAAAAAAAAAA.tmp")
    File.write!(artifact, "partial")
    File.chmod!(artifact, 0o600)

    assert {:ok, [%{id: "session-01"}]} = Catalog.list(adapter(), workspace, environment)

    File.chmod!(artifact, 0o644)
    assert {:error, error} = Catalog.list(adapter(), workspace, environment)
    assert error.code == "session_storage_unsafe"
  end

  test "fetches and archives a known ID when the complete catalog exceeds its limit", %{
    tmp_dir: root
  } do
    {workspace, environment} = context(root)
    create_session(workspace, environment, "session-01", "qwen3")
    assert {:ok, scope} = Scope.new(workspace, environment)

    Enum.each(1..256, fn index ->
      File.mkdir!(Path.join(scope.sessions, "overflow-#{index}"))
    end)

    assert {:error, too_large} = Catalog.list(adapter(), workspace, environment)
    assert too_large.code == "session_catalog_too_large"

    assert {:ok, %{id: "session-01", archive: :active}} =
             Catalog.fetch(adapter(), workspace, "session-01", environment)

    assert {:ok, %{archive: {:archived, _timestamp}}} =
             Catalog.archive(adapter(), workspace, "session-01", environment)
  end

  test "resolves active and archived entries by ID or unique label", %{tmp_dir: root} do
    {workspace, environment} = context(root)
    create_session(workspace, environment, "one", "qwen3")
    create_session(workspace, environment, "two", "qwen3")
    assert {:ok, _entry} = Catalog.rename(adapter(), workspace, "one", "Review", environment)
    assert {:ok, _entry} = Catalog.archive(adapter(), workspace, "two", environment)
    assert {:ok, entries} = Catalog.list(adapter(), workspace, environment)

    assert {:ok, %{id: "one"}} = Catalog.resolve(entries, "Review", :active)
    assert {:ok, %{id: "two"}} = Catalog.resolve(entries, "two", :archived)
    assert {:ok, %{id: "two"}} = Catalog.resolve(entries, "two", :any)
    assert {:error, :not_found} = Catalog.resolve(entries, "two", :active)
  end

  test "serializes metadata mutations with active session work", %{tmp_dir: root} do
    {workspace, environment} = context(root)
    create_session(workspace, environment, "session-01", "qwen3")
    assert {:ok, store} = Store.open(:manage, workspace, "session-01", environment)

    assert {:error, locked} =
             Catalog.archive(adapter(), workspace, "session-01", environment)

    assert locked.code == "session_locked"
    assert :ok = Store.close(store)
    assert {:ok, _archived} = Catalog.archive(adapter(), workspace, "session-01", environment)
  end

  test "repeated archive and restore operations converge without changing the archive time", %{
    tmp_dir: root
  } do
    {workspace, environment} = context(root)
    create_session(workspace, environment, "session-01", "qwen3")

    assert {:ok, first} = Catalog.archive(adapter(), workspace, "session-01", environment)

    later = {Local, [clock: fn -> ~U[2026-09-07 13:00:00Z] end]}
    assert {:ok, repeated} = Catalog.archive(later, workspace, "session-01", environment)
    assert repeated.archive == first.archive

    assert {:ok, restored} = Catalog.restore(adapter(), workspace, "session-01", environment)
    assert restored.archive == :active

    assert {:ok, repeated_restore} =
             Catalog.restore(adapter(), workspace, "session-01", environment)

    assert repeated_restore.archive == :active
  end

  defp context(root) do
    workspace = Path.join(root, "workspace")
    File.mkdir_p!(workspace)
    {workspace, %{"XDG_STATE_HOME" => Path.join(root, "state")}}
  end

  defp adapter do
    {Local, [clock: fn -> ~U[2026-09-07 12:00:00Z] end]}
  end

  defp create_session(workspace, environment, identifier, model) do
    assert {:ok, store} = Store.initialize(workspace, identifier, environment)
    assert :ok = Binding.Local.create(store.paths, session_binding(model))
    paths = store.paths
    assert :ok = Store.close(store)
    paths
  end

  defp session_binding(model) do
    %Binding{
      adapter: "Draught.Provider.Ollama",
      capabilities: String.duplicate("a", 64),
      connection: String.duplicate("b", 64),
      model: model,
      profile: "ollama",
      provider: "ollama",
      version: 2
    }
  end

  defp secure_scope(scope) do
    for directory <- [
          scope.root,
          Path.join(scope.root, "workspaces"),
          scope.workspace,
          scope.sessions
        ] do
      File.chmod!(directory, 0o700)
    end
  end
end
