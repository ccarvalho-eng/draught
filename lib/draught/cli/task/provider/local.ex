defmodule Draught.CLI.Task.Provider.Local do
  @moduledoc """
  Routes local CLI provider configuration to its Ollama or OpenAI-compatible builder.
  """

  @behaviour Draught.CLI.Task.Provider.Adapter

  alias Draught.CLI.Configuration
  alias Draught.CLI.Task.Provider.Local.Ollama
  alias Draught.CLI.Task.Provider.Local.OpenAICompatible
  alias Draught.Validation.Attributes

  @impl Draught.CLI.Task.Provider.Adapter
  def build(%Configuration{provider: :ollama} = configuration, dependencies) do
    with {:ok, normalized} <- normalize(dependencies) do
      Ollama.build(configuration, normalized)
    end
  end

  def build(%Configuration{provider: :openai_compatible} = configuration, dependencies) do
    with {:ok, normalized} <- normalize(dependencies) do
      OpenAICompatible.build(configuration, normalized)
    end
  end

  defp normalize(dependencies) do
    Attributes.normalize(dependencies, [:discovery_http, :provider_transport])
  end
end
