defmodule Draught.Telemetry.ToolSpan do
  @moduledoc """
  Instruments tool execution with outcome and provenance metadata.

  Metadata is derived from canonical tool results. Web tools are identified as
  untrusted web input when a result does not carry explicit provenance.
  """

  alias Draught.Telemetry.Outcome
  alias Draught.Telemetry.Span
  alias Draught.Tool.Result
  alias Draught.Tool.Result.Provenance

  @prefix [:draught, :tool, :execution]
  @web_tools ["web_fetch", "web_search"]

  @doc "Runs one tool boundary operation inside a sanitized span."
  @spec run((-> result)) :: result when result: term()
  def run(function) do
    Span.run(@prefix, %{}, function, fn result ->
      {%{}, metadata(result)}
    end)
  end

  defp metadata({:ok, %Result{provenance: %Provenance{} = provenance}} = result) do
    result
    |> Outcome.result()
    |> Map.merge(%{origin: provenance.origin, trust: provenance.trust})
  end

  defp metadata({:ok, %Result{name: name}} = result) when name in @web_tools do
    result
    |> Outcome.result()
    |> Map.merge(%{origin: :web, trust: :untrusted})
  end

  defp metadata(result) do
    Outcome.result(result)
  end
end
