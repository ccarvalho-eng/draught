defmodule Draught.CLI.Session.Binding.CapabilityIdentity do
  @moduledoc """
  Derives a stable non-secret identity for negotiated provider and web capabilities.

  The identity binds session continuation to the exact feature and context
  contract used when the session was created without persisting provider
  configuration.
  """

  alias Draught.Provider.Capabilities
  alias Draught.Web.Capability
  alias Draught.Web.Policy

  @doc "Returns the lowercase SHA-256 identity of one canonical capability set."
  @spec fingerprint(Capabilities.t(), Capability.t()) :: String.t()
  def fingerprint(%Capabilities{} = capabilities, %Capability{} = web) do
    capabilities
    |> ordered_values(web)
    |> Enum.map_join(&frame/1)
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp ordered_values(capabilities, web) do
    status = Policy.status(web.policy)

    [
      capabilities.chat,
      capabilities.streaming,
      capabilities.tool_calls,
      capabilities.reasoning,
      capabilities.usage,
      capabilities.context_window,
      status.fetch,
      status.search,
      adapter_name(web.fetch),
      adapter_name(web.search),
      search_endpoint(web.search)
    ]
  end

  defp adapter_name(nil) do
    nil
  end

  defp adapter_name({module, _configuration}) do
    Atom.to_string(module)
  end

  defp search_endpoint({_module, configuration}) when is_list(configuration) do
    Keyword.get(configuration, :endpoint)
  end

  defp search_endpoint(_adapter) do
    nil
  end

  defp frame(nil) do
    "0:"
  end

  defp frame(value) do
    encoded = to_string(value)
    "#{byte_size(encoded)}:#{encoded}"
  end
end
