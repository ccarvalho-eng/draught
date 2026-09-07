defmodule Draught.CLI.Task.Preparation.Builder do
  @moduledoc """
  Assembles an immutable task preparation from messages, provider selection, tools, and limits.
  """

  alias Draught.CLI.Task.Preparation
  alias Draught.CLI.Task.Preparation.Builder.Assembly
  alias Draught.CLI.Task.Provider.Selection
  alias Draught.Provider.Capabilities
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @doc "Coordinates pure construction of one execution preparation."
  @spec build(term(), Selection.t(), String.t(), map()) :: Error.result(Preparation.t())
  def build(prompt, %Selection{} = selection, workspace, attributes) do
    with :ok <- web_disabled(attributes),
         {:ok, provider_mode} <- provider_mode(selection, attributes) do
      Assembly.build(prompt, selection, workspace, attributes, provider_mode)
    end
  end

  defp web_disabled(attributes) do
    case Map.get(attributes, :web, false) do
      false -> :ok
      true -> Error.single([:web], :invalid_value, "Web execution is not available yet")
      _value -> Error.single([:web], :invalid_type, "must be a boolean")
    end
  end

  defp provider_mode(selection, attributes) do
    with {:ok, mode} <-
           attributes
           |> Map.get(:provider_mode, :complete)
           |> Value.enum([:complete, :stream], [:provider_mode]),
         :ok <- require_streaming(selection.capabilities, mode) do
      {:ok, mode}
    end
  end

  defp require_streaming(_capabilities, :complete) do
    :ok
  end

  defp require_streaming(capabilities, :stream) do
    Capabilities.require(capabilities, :streaming)
  end
end
