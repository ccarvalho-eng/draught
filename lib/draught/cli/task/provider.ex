defmodule Draught.CLI.Task.Provider do
  @moduledoc """
  Validates and dispatches construction of the provider selected for a CLI task.
  """

  alias Draught.CLI.Configuration
  alias Draught.CLI.Task.Provider.Failure
  alias Draught.CLI.Task.Provider.Selection
  alias Draught.Error.Normalized
  alias Draught.Validation.Error

  @doc "Builds a provider through the injected provider-construction boundary."
  @spec build(Configuration.t(), {module(), term()}) ::
          {:ok, Selection.t()}
          | {:error, Draught.Error.Normalized.t() | Draught.Validation.Error.t()}
  def build(%Configuration{} = configuration, {module, dependency}) do
    configuration
    |> module.build(dependency)
    |> normalize()
  end

  defp normalize({:ok, %Selection{} = selection}) do
    Selection.new(selection.adapter, selection.model)
  end

  defp normalize({:error, %Normalized{}} = result) do
    result
  end

  defp normalize({:error, %Error{}} = result) do
    result
  end

  defp normalize(_result) do
    {:error, Failure.invalid_selection()}
  end
end
