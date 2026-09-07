defmodule Draught.Telemetry.Measurements do
  @moduledoc false

  alias Draught.Provider.Response
  alias Draught.Provider.Usage
  alias Draught.Telemetry

  @maximum_duration_ms 86_400_000
  @usage_keys [
    :cached_tokens,
    :input_tokens,
    :output_tokens,
    :reasoning_tokens,
    :total_tokens
  ]

  @doc "Builds the standard span start measurement."
  @spec start() :: %{system_time: integer()}
  def start do
    %{system_time: System.system_time()}
  end

  @doc "Builds bounded duration and count measurements."
  @spec completion(integer()) :: %{count: pos_integer(), duration: non_neg_integer()}
  def completion(started_at) do
    duration = System.monotonic_time() - started_at
    %{count: 1, duration: bound_duration(duration)}
  end

  @doc "Builds bounded token usage measurements from a canonical result."
  @spec usage(term()) :: map()
  def usage({:ok, %Response{usage: %Usage{} = usage}}) do
    project_usage(usage)
  end

  def usage(_result) do
    {:ok, usage} = Usage.new(input_tokens: 0, output_tokens: 0)
    project_usage(usage)
  end

  defp project_usage(usage) do
    usage
    |> Map.from_struct()
    |> Map.take(@usage_keys)
    |> Map.new(fn {key, value} -> {key, bound_count(value)} end)
  end

  defp bound_count(value) when is_integer(value) and value >= 0 do
    min(value, Telemetry.maximum_count())
  end

  defp bound_count(_value) do
    0
  end

  defp bound_duration(value) do
    maximum = System.convert_time_unit(@maximum_duration_ms, :millisecond, :native)

    value
    |> max(0)
    |> min(maximum)
  end
end
