defmodule Draught.CLI.Task.Approval.Presentation do
  @moduledoc """
  Builds a complete terminal view from validated approval metadata.

  Exact file replacements gain a safe proposed diff when their structured
  fields are available. Commands use a compact shell-style line when every
  token can be represented safely. Other operations retain their complete
  JSON view.
  """

  alias Draught.CLI.Task.Approval.Command
  alias Draught.CLI.UI.Owl.Diff
  alias Draught.CLI.UI.Owl.JSON
  alias Draught.Tool.Approval.Request

  @doc "Renders a bounded, tool-specific approval view."
  @spec render(Request.t(), boolean()) :: {:ok, iodata()} | {:error, :unavailable}
  def render(%Request{tool: "run_command", preview: preview} = request, styled?)
      when is_binary(preview) and is_boolean(styled?) do
    case Command.render(preview) do
      {:ok, command} -> {:ok, command}
      {:error, :unavailable} -> render_json(request, styled?)
    end
  end

  def render(%Request{preview: preview} = request, styled?)
      when is_binary(preview) and is_boolean(styled?) do
    render_json(request, styled?)
  end

  def render(%Request{}, _styled?) do
    {:error, :unavailable}
  end

  defp render_json(%Request{preview: preview} = request, styled?) do
    with {:ok, json} <- JSON.render(preview, styled?) do
      {:ok, [diff(request, styled?), "Operation (JSON):\n", json]}
    end
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
