defmodule Draught.CLI.Session.Store.PathsTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Session.Store.Paths

  @moduletag :tmp_dir

  test "scopes sessions beneath trusted user state without exposing the workspace", %{
    tmp_dir: tmp_dir
  } do
    workspace = Path.join(tmp_dir, "workspace")
    state_home = Path.join(tmp_dir, "state")
    File.mkdir_p!(workspace)

    assert {:ok, paths} =
             Paths.new(workspace, "review", %{"XDG_STATE_HOME" => state_home})

    assert paths.root == Path.join(state_home, "draught")
    assert paths.session == Path.join([paths.workspace, "sessions", "review"])
    assert paths.marker == Path.join(paths.session, ".draught-session")
    assert byte_size(paths.key) == 64
    refute paths.session =~ workspace
  end

  test "canonical workspace aliases share a scope", %{tmp_dir: tmp_dir} do
    workspace = Path.join(tmp_dir, "workspace")
    alias_path = Path.join(tmp_dir, "workspace-alias")
    state_home = Path.join(tmp_dir, "state")
    File.mkdir_p!(workspace)
    File.ln_s!(workspace, alias_path)
    environment = %{"XDG_STATE_HOME" => state_home}

    assert {:ok, direct} = Paths.new(workspace, "review", environment)
    assert {:ok, aliased} = Paths.new(alias_path, "review", environment)
    assert direct.workspace == aliased.workspace
    assert direct.key == aliased.key
  end

  test "canonical user-state aliases share paths and a lease scope", %{tmp_dir: tmp_dir} do
    workspace = Path.join(tmp_dir, "workspace")
    state_home = Path.join(tmp_dir, "state")
    state_alias = Path.join(tmp_dir, "state-alias")
    File.mkdir_p!(workspace)
    File.mkdir_p!(state_home)
    File.ln_s!(state_home, state_alias)

    assert {:ok, direct} =
             Paths.new(workspace, "review", %{"XDG_STATE_HOME" => state_home})

    assert {:ok, aliased} =
             Paths.new(workspace, "review", %{"XDG_STATE_HOME" => state_alias})

    assert direct.root == aliased.root
    assert direct.session == aliased.session
    assert direct.key == aliased.key
  end

  test "same session identifier in different workspaces does not collide", %{tmp_dir: tmp_dir} do
    first = Path.join(tmp_dir, "first")
    second = Path.join(tmp_dir, "second")
    state_home = Path.join(tmp_dir, "state")
    File.mkdir_p!(first)
    File.mkdir_p!(second)
    environment = %{"XDG_STATE_HOME" => state_home}

    assert {:ok, first_paths} = Paths.new(first, "review", environment)
    assert {:ok, second_paths} = Paths.new(second, "review", environment)
    refute first_paths.workspace == second_paths.workspace
    refute first_paths.key == second_paths.key
  end

  test "separates lease scopes for different user-state roots", %{tmp_dir: tmp_dir} do
    workspace = Path.join(tmp_dir, "workspace")
    File.mkdir_p!(workspace)

    assert {:ok, first} =
             Paths.new(workspace, "review", %{"XDG_STATE_HOME" => Path.join(tmp_dir, "one")})

    assert {:ok, second} =
             Paths.new(workspace, "review", %{"XDG_STATE_HOME" => Path.join(tmp_dir, "two")})

    refute first.key == second.key
  end

  test "uses an absolute HOME fallback and never falls back to the workspace", %{tmp_dir: tmp_dir} do
    workspace = Path.join(tmp_dir, "workspace")
    home = Path.join(tmp_dir, "home")
    File.mkdir_p!(workspace)

    assert {:ok, paths} =
             Paths.new(workspace, "review", %{
               "HOME" => home,
               "XDG_STATE_HOME" => "relative/state"
             })

    assert paths.root == Path.join([home, ".local", "state", "draught"])

    assert {:error, error} = Paths.new(workspace, "review", %{})
    assert [%{code: :required, path: [:state_home]}] = error.violations
  end

  test "validates the portable session identifier", %{tmp_dir: tmp_dir} do
    workspace = Path.join(tmp_dir, "workspace")
    File.mkdir_p!(workspace)

    assert {:error, error} =
             Paths.new(workspace, "../escape", %{"XDG_STATE_HOME" => tmp_dir})

    assert [%{path: [:session_id]}] = error.violations
  end
end
