defmodule Draught.CLI.Task.Stream.Projector.ToolTarget do
  @moduledoc """
  Extracts a bounded display target from allowlisted filesystem tool calls.

  The projection accepts only relative paths and never forwards the complete
  tool argument map to a renderer.
  """

  alias Draught.CLI.Output.Sanitizer
  alias Draught.Tool.Call

  @maximum_bytes 160
  @path_tools ~w(list_directory read_file replace_in_file search_workspace)

  @doc "Returns a safe relative path for a supported call, or nil."
  @spec from_call(Call.t()) :: String.t() | nil
  def from_call(%Call{name: name, arguments: %{"path" => path}})
      when name in @path_tools and is_binary(path) do
    path
    |> Sanitizer.text()
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
    |> Sanitizer.text(@maximum_bytes)
    |> visible_target()
  end

  def from_call(%Call{}) do
    nil
  end

  defp visible_target("") do
    nil
  end

  defp visible_target(target) do
    if Path.type(target) == :relative and not String.starts_with?(target, "~") do
      target
    end
  end
end
