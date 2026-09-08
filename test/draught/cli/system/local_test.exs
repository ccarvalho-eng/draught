defmodule Draught.CLI.System.LocalTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.System.Local

  @tag :tmp_dir
  test "reads only bounded regular non-symlink files", %{tmp_dir: directory} do
    regular = Path.join(directory, "config.json")
    symlink = Path.join(directory, "config-link.json")
    File.write!(regular, "content")
    File.ln_s!(regular, symlink)

    assert Local.read_file(regular, 7, nil) == {:ok, "content"}
    assert Local.read_file(regular, 6, nil) == {:error, :too_large}
    assert Local.read_file(symlink, 32, nil) == {:error, :unsafe_file}
    missing = Path.join(directory, "missing")
    assert Local.read_file(missing, 32, nil) == :missing
  end

  @tag :tmp_dir
  test "atomically creates and replaces owner-only regular files", %{tmp_dir: directory} do
    path = Path.join([directory, "draught", "config.json"])
    parent = Path.dirname(path)

    assert Local.write_file(path, "first", nil) == :ok
    assert File.read!(path) == "first"
    assert file_mode(path) == 0o600
    assert file_mode(parent) == 0o700

    assert Local.write_file(path, "second", nil) == :ok
    assert File.read!(path) == "second"
    temporary_pattern = Path.join(parent, ".config-*.tmp")
    assert Path.wildcard(temporary_pattern) == []
  end

  @tag :tmp_dir
  test "rejects unsafe write destinations without changing their targets", %{tmp_dir: directory} do
    target = Path.join(directory, "target.json")
    symlink = Path.join(directory, "config.json")
    File.write!(target, "unchanged")
    File.ln_s!(target, symlink)

    assert Local.write_file(symlink, "replacement", nil) == {:error, :unsafe_file}
    assert File.read!(target) == "unchanged"
  end

  @tag :tmp_dir
  test "checks workspace accessibility without mutation", %{tmp_dir: directory} do
    file = Path.join(directory, "file")
    File.write!(file, "")

    assert Local.workspace(directory, nil) == :ok
    assert Local.workspace(file, nil) == {:error, :not_directory}
    missing = Path.join(directory, "missing")
    assert Local.workspace(missing, nil) == {:error, :inaccessible}
  end

  test "returns bounded operating-system observations" do
    assert {:ok, cwd} = Local.cwd(nil)
    assert is_binary(cwd)
    assert is_map(Local.environment(nil))
    assert Local.tty?(:stdout, nil) in [true, false]

    assert match?({:ok, columns} when columns > 0, Local.columns(nil)) or
             Local.columns(nil) == {:error, :unavailable}
  end

  defp file_mode(path) do
    path
    |> File.stat!()
    |> Map.fetch!(:mode)
    |> Bitwise.band(0o777)
  end
end
