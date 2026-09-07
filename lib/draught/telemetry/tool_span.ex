defmodule Draught.Telemetry.ToolSpan do
  @moduledoc false

  alias Draught.Telemetry.Outcome
  alias Draught.Telemetry.Span

  @prefix [:draught, :tool, :execution]

  @doc "Runs one tool boundary operation inside a sanitized span."
  @spec run((-> result)) :: result when result: term()
  def run(function) do
    Span.run(@prefix, %{}, function, fn result ->
      {%{}, Outcome.result(result)}
    end)
  end
end
