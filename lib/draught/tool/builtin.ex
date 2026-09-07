defmodule Draught.Tool.Builtin do
  @moduledoc """
  Constructs the standard Draught coding-tool catalog.
  """

  alias Draught.Tool.Builtin.Builders
  alias Draught.Tool.Definition
  alias Draught.Tool.Registry
  alias Draught.Validation.Error

  @doc "Builds the standard definitions in stable declaration order."
  @spec definitions(keyword()) :: Error.result([Definition.t()])
  def definitions(options \\ []) do
    options
    |> Builders.modules()
    |> Enum.reduce_while({:ok, []}, &build/2)
    |> reverse()
  end

  @doc "Builds an immutable registry containing the standard tools."
  @spec registry(keyword()) :: Error.result(Registry.t())
  def registry(options \\ []) do
    with {:ok, definitions} <- definitions(options) do
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
