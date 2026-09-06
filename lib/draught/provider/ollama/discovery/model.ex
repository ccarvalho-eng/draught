defmodule Draught.Provider.Ollama.Discovery.Model do
  @moduledoc """
  Native Ollama model details used during provider selection.
  """

  alias Draught.Provider.Capabilities

  @enforce_keys [:name, :capabilities]
  defstruct [:name, :capabilities]

  @type t :: %__MODULE__{
          name: String.t(),
          capabilities: Capabilities.t()
        }
end
