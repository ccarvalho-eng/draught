defmodule Draught.Provider.Ollama.Capability.Validator do
  @moduledoc false

  alias Draught.Provider.Capabilities
  alias Draught.Provider.Ollama.Protocol

  @doc "Validates every configured capability requirement."
  @spec validate(Capabilities.t(), [Capabilities.feature()]) ::
          :ok | {:error, Draught.Error.Normalized.t()}
  def validate(%Capabilities{} = capabilities, requirements) do
    Enum.reduce_while(requirements, :ok, fn requirement, :ok ->
      requirement_result(Capabilities.supports?(capabilities, requirement), requirement)
    end)
  end

  defp requirement_result(true, _requirement) do
    {:cont, :ok}
  end

  defp requirement_result(false, requirement) do
    {:halt, Protocol.unsupported(requirement)}
  end
end
