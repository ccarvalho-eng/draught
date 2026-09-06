defmodule Draught.Provider.Ollama.Runtime do
  @moduledoc """
  Holds the selected Ollama capabilities and OpenAI-compatible runtime.
  """

  alias Draught.Provider.Capabilities
  alias Draught.Provider.OpenAI

  @enforce_keys [:capabilities, :openai]
  defstruct [:capabilities, :openai]

  @type t :: %__MODULE__{
          capabilities: Capabilities.t(),
          openai: OpenAI.Runtime.t()
        }
end

defimpl Inspect, for: Draught.Provider.Ollama.Runtime do
  import Inspect.Algebra

  @spec inspect(Draught.Provider.Ollama.Runtime.t(), Inspect.Opts.t()) :: Inspect.Algebra.t()
  def inspect(_runtime, _options) do
    concat(["#Draught.Provider.Ollama.Runtime<redacted>"])
  end
end
