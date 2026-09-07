defmodule Draught.CLI.Doctor.Provider do
  @moduledoc """
  Dispatches read-only provider diagnostics for the resolved CLI configuration.
  """

  alias Draught.CLI.Configuration
  alias Draught.CLI.Doctor.Check
  alias Draught.CLI.Doctor.Provider.Ollama

  @doc "Dispatches a read-only diagnostic check for the selected provider."
  @spec check(Configuration.t(), module()) :: Check.t()
  def check(%Configuration{provider: :ollama} = configuration, discovery_http) do
    Ollama.check(configuration, discovery_http)
  end

  def check(%Configuration{provider: :openai_compatible, model: nil}, _discovery_http) do
    Check.new(
      "Provider",
      :error,
      "an OpenAI-compatible model is not selected",
      hint: "Set a model in configuration or with --model."
    )
  end

  def check(%Configuration{provider: :openai_compatible}, _discovery_http) do
    Check.new(
      "Provider",
      :error,
      "OpenAI-compatible connectivity and capabilities were not checked",
      hint: "Use a provider diagnostic adapter before relying on this configuration."
    )
  end
end
