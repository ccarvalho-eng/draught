defmodule Draught.Distribution.Burrito.MuslRuntime do
  @moduledoc """
  Embeds a verified musl loader when Burrito uses a local Linux ERTS archive.

  Burrito normally performs this step while resolving its own precompiled
  Linux runtime. A release build that supplies an already verified local ERTS
  archive bypasses that resolver, so this adapter preserves the loader contract
  from target qualifiers prepared by the release configuration.
  """

  @behaviour Burrito.Builder.Step

  alias Burrito.Builder.Context
  alias Burrito.Builder.Target

  @impl Burrito.Builder.Step
  @spec execute(Context.t()) :: Context.t()
  def execute(
        %Context{
          target: %Target{os: :linux, erts_source: {:local, _location}} = target
        } = context
      ) do
    archive = required_qualifier!(target, :musl_archive)
    expected_digest = required_qualifier!(target, :musl_sha256)
    runtime = File.read!(archive)

    verify_digest!(runtime, expected_digest)

    context
    |> destination()
    |> File.write!(runtime)

    build_environment = {
      "__BURRITO_MUSL_RUNTIME_PATH",
      "/tmp/libc-musl-#{expected_digest}.so"
    }

    %{context | extra_build_env: [build_environment | context.extra_build_env]}
  end

  def execute(%Context{} = context) do
    context
  end

  defp required_qualifier!(target, name) do
    case Keyword.fetch(target.qualifiers, name) do
      {:ok, value} when is_binary(value) and value != "" -> value
      _result -> raise "missing Burrito #{name} qualifier for verified Linux ERTS"
    end
  end

  defp verify_digest!(runtime, expected_digest) do
    digest =
      runtime
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    if digest != expected_digest do
      raise "verified Linux musl runtime digest mismatch"
    end
  end

  defp destination(context) do
    Path.join([context.self_dir, "src", "musl-runtime.so"])
  end
end
