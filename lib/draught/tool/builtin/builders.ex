defmodule Draught.Tool.Builtin.Builders do
  @moduledoc """
  Selects the definition builders used by the standard tool catalog.

  Workspace tools retain a stable order. Web tools are appended only when the
  supplied capability explicitly enables their corresponding operation.
  """

  alias Draught.Tool.Builtin.ListDirectory
  alias Draught.Tool.Builtin.ReadFile
  alias Draught.Tool.Builtin.ReplaceInFile
  alias Draught.Tool.Builtin.RunCommand
  alias Draught.Tool.Builtin.SearchWorkspace
  alias Draught.Tool.Builtin.WebFetch
  alias Draught.Tool.Builtin.WebSearch
  alias Draught.Web.Capability

  @standard [ReadFile, ListDirectory, SearchWorkspace, ReplaceInFile, RunCommand]

  @doc "Returns enabled definition builders in stable declaration order."
  @spec modules(keyword()) :: [module()]
  def modules(options) do
    case Keyword.get(options, :web) do
      %Capability{} = capability -> @standard ++ web(capability)
      nil -> @standard
    end
  end

  defp web(capability) do
    []
    |> maybe_add(WebSearch, Capability.enabled?(capability, :search))
    |> maybe_add(WebFetch, Capability.enabled?(capability, :fetch))
    |> Enum.reverse()
  end

  defp maybe_add(builders, builder, true) do
    [builder | builders]
  end

  defp maybe_add(builders, _builder, false) do
    builders
  end
end
