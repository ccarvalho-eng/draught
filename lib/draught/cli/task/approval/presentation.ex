defmodule Draught.CLI.Task.Approval.Presentation do
  @moduledoc """
  Builds a complete terminal view from validated approval metadata.

  Exact file replacements gain a safe proposed diff when their structured
  fields are available. Every operation retains its complete JSON view; an
  optional diff never substitutes for or changes the authoritative request.
  """

  alias Draught.CLI.UI.Owl.Diff
  alias Draught.CLI.UI.Owl.JSON
  alias Draught.Tool.Approval.Request

  @doc "Renders an optional tool-specific view followed by complete operation JSON."
  @spec render(Request.t(), boolean()) :: {:ok, iodata()} | {:error, :unavailable}
  def render(%Request{preview: preview} = request, styled?)
      when is_binary(preview) and is_boolean(styled?) do
    with {:ok, json} <- JSON.render(preview, styled?) do
      {:ok, [diff(request, styled?), "Operation (JSON):\n", json]}
    end
  end

  def render(%Request{}, _styled?) do
    {:error, :unavailable}
  end

  defp diff(%Request{tool: "replace_in_file", preview: preview}, styled?) do
    with {:ok, operation} <- Jason.decode(preview),
         {:ok, rendered} <- Diff.replace_in_file(operation, styled?) do
      ["Proposed diff:\n", rendered, "\n"]
    else
      _unavailable -> []
    end
  end

  defp diff(%Request{}, _styled?) do
    []
  end
end
