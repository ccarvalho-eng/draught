defmodule Draught.Execution.Runner.LimitsTest do
  use ExUnit.Case, async: true

  alias Draught.Execution.Runner.Limits

  test "provides bounded defaults" do
    assert {:ok, limits} = Limits.new()
    assert limits.max_iterations == 12
    assert limits.max_output_bytes == 1024 * 1024
    assert limits.provider_timeout_ms == 120_000
    assert limits.tool_timeout_ms == 30_000
  end

  test "rejects values beyond each public bound" do
    assert {:error, iterations} = Limits.new(max_iterations: 101)
    assert first_path(iterations) == [:max_iterations]

    assert {:error, output} = Limits.new(max_output_bytes: 16 * 1024 * 1024 + 1)
    assert first_path(output) == [:max_output_bytes]

    assert {:error, provider} = Limits.new(provider_timeout_ms: 600_001)
    assert first_path(provider) == [:provider_timeout_ms]

    assert {:error, tool} = Limits.new(tool_timeout_ms: 600_001)
    assert first_path(tool) == [:tool_timeout_ms]
  end

  defp first_path(error) do
    error.violations
    |> List.first()
    |> Map.fetch!(:path)
  end
end
