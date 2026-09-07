defmodule Draught.Tool.Builtin do
  @moduledoc """
  Constructs the standard Draught coding-tool catalog.
  """

  alias Draught.Tool.Builtin.ListDirectory
  alias Draught.Tool.Builtin.ReadFile
  alias Draught.Tool.Builtin.ReplaceInFile
  alias Draught.Tool.Builtin.RunCommand
  alias Draught.Tool.Builtin.SearchWorkspace
  alias Draught.Tool.Definition
  alias Draught.Tool.Registry
  alias Draught.Validation.Error

  @builders [ReadFile, ListDirectory, SearchWorkspace, ReplaceInFile, RunCommand]

  @doc "Builds the standard definitions in stable declaration order."
  @spec definitions() :: Error.result([Definition.t()])
  def definitions do
    @builders
    |> Enum.reduce_while({:ok, []}, &build/2)
    |> reverse()
  end

  @doc "Builds an immutable registry containing the standard tools."
  @spec registry() :: Error.result(Registry.t())
  def registry do
    with {:ok, definitions} <- definitions() do
      Registry.new(definitions)
    end
  end

  defp build(module, {:ok, definitions}) do
    case module.definition() do
      {:ok, definition} -> {:cont, {:ok, [definition | definitions]}}
      {:error, %Error{}} = result -> {:halt, result}
    end
  end

  defp reverse({:ok, definitions}) do
    {:ok, Enum.reverse(definitions)}
  end

  defp reverse({:error, %Error{}} = result) do
    result
  end
end
