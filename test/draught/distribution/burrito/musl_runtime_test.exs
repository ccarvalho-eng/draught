defmodule Draught.Distribution.Burrito.MuslRuntimeTest do
  use ExUnit.Case, async: true

  alias Burrito.Builder.Context
  alias Burrito.Builder.Target
  alias Draught.Distribution.Burrito.MuslRuntime

  @moduletag :tmp_dir

  test "embeds the verified loader for a local Linux ERTS archive", %{tmp_dir: root} do
    runtime = "verified-musl-runtime"
    archive = Path.join(root, "musl.so")
    digest = digest(runtime)

    root
    |> Path.join("src")
    |> File.mkdir_p!()

    File.write!(archive, runtime)

    context = context(root, {:local, path: "erts.tar.gz"}, archive, digest)

    assert %Context{extra_build_env: [environment]} = MuslRuntime.execute(context)
    assert environment == {"__BURRITO_MUSL_RUNTIME_PATH", "/tmp/libc-musl-#{digest}.so"}

    assert root
           |> destination()
           |> File.read!() == runtime
  end

  test "rejects a loader whose bytes do not match the pinned digest", %{tmp_dir: root} do
    archive = Path.join(root, "musl.so")

    root
    |> Path.join("src")
    |> File.mkdir_p!()

    File.write!(archive, "changed-runtime")

    context = context(root, {:local, path: "erts.tar.gz"}, archive, digest("expected"))

    assert_raise RuntimeError, "verified Linux musl runtime digest mismatch", fn ->
      MuslRuntime.execute(context)
    end

    refute root
           |> destination()
           |> File.exists?()
  end

  test "rejects incomplete local Linux runtime configuration", %{tmp_dir: root} do
    context = context(root, {:local, path: "erts.tar.gz"}, nil, digest("runtime"))

    assert_raise RuntimeError,
                 "missing Burrito musl_archive qualifier for verified Linux ERTS",
                 fn ->
                   MuslRuntime.execute(context)
                 end
  end

  test "leaves Burrito's precompiled runtime flow unchanged", %{tmp_dir: root} do
    context = context(root, {:precompiled, version: "28.4.1"}, nil, nil)

    assert MuslRuntime.execute(context) == context
  end

  defp context(root, source, archive, digest) do
    target = %Target{
      alias: :linux_x86_64,
      cpu: :x86_64,
      cross_build: true,
      debug?: false,
      erts_source: source,
      os: :linux,
      qualifiers: [musl_archive: archive, musl_sha256: digest]
    }

    %Context{
      extra_build_env: [],
      halted: false,
      mix_release: %Mix.Release{},
      self_dir: root,
      target: target,
      work_dir: root
    }
  end

  defp digest(value) do
    value
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp destination(root) do
    Path.join([root, "src", "musl-runtime.so"])
  end
end
