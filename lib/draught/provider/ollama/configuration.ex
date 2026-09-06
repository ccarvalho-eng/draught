defmodule Draught.Provider.Ollama.Configuration do
  @moduledoc """
  Validated Ollama preset and discovery settings.
  """

  alias Draught.Provider.Ollama.Configuration.Builder
  alias Draught.Provider.OpenAI.Configuration
  alias Draught.Validation.Error

  @enforce_keys [:base_url, :model, :required_capabilities, :openai, :discovery]
  defstruct [:base_url, :model, :required_capabilities, :openai, :discovery]

  @type t :: %__MODULE__{
          base_url: String.t(),
          model: String.t() | nil,
          required_capabilities: [Draught.Provider.Capabilities.feature()],
          openai: Configuration.t(),
          discovery: Draught.Provider.Ollama.Discovery.Configuration.t()
        }

  @doc "Builds validated Ollama settings and the corresponding OpenAI preset."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes \\ %{}) do
    Builder.new(attributes)
  end

  @doc "Returns OpenAI-compatible settings fixed to the selected model."
  @spec for_model(t(), String.t()) :: Configuration.t()
  def for_model(%__MODULE__{openai: %Configuration{} = openai}, model) do
    %Configuration{openai | model: model}
  end
end
