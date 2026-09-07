defmodule Draught.CLI.Session.Binding.CapabilityIdentity do
  @moduledoc """
  Derives a stable non-secret identity for negotiated provider capabilities.

  The identity binds session continuation to the exact feature and context
  contract used when the session was created without persisting provider
  configuration.
  """

  alias Draught.Provider.Capabilities

  @doc "Returns the lowercase SHA-256 identity of one canonical capability set."
  @spec fingerprint(Capabilities.t()) :: String.t()
  def fingerprint(%Capabilities{} = capabilities) do
    capabilities
    |> ordered_values()
    |> Enum.map_join(&frame/1)
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp ordered_values(capabilities) do
    [
      capabilities.chat,
      capabilities.streaming,
      capabilities.tool_calls,
      capabilities.reasoning,
      capabilities.usage,
      capabilities.context_window
    ]
  end

  defp frame(nil) do
    "0:"
  end

  defp frame(value) do
    encoded = to_string(value)
    "#{byte_size(encoded)}:#{encoded}"
  end
end
