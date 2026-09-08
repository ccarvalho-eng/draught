defmodule Draught.CLI.Task.Preparation.Web do
  @moduledoc """
  Constructs the trusted web capability selected by CLI configuration.

  Disabled tasks receive no web adapters. Enabled tasks receive only the
  guarded fetch transport until a concrete search adapter is configured.
  """

  alias Draught.Validation.Error
  alias Draught.Web.Capability
  alias Draught.Web.Fetch.Transport.Mint
  alias Draught.Web.Search.Transport.Searxng

  @doc "Builds the effective CLI web capability from a validated setting."
  @type setting ::
          boolean() | %{fetch: boolean(), search: boolean(), search_url: String.t() | nil}

  @spec capability(setting()) :: Error.result(Capability.t())
  def capability(false) do
    Capability.new()
  end

  def capability(true) do
    Capability.new(
      policy: [fetch: true],
      fetch: {Mint, []}
    )
  end

  def capability(%{fetch: fetch, search: search, search_url: search_url} = setting)
      when map_size(setting) == 3 and is_boolean(fetch) and is_boolean(search) do
    build(fetch, search, search_url)
  end

  def capability(_setting) do
    Error.single([:web], :invalid_value, "must contain bounded fetch and search settings")
  end

  defp build(fetch, true, search_url) when is_binary(search_url) do
    Capability.new(
      policy: [fetch: fetch, search: true],
      fetch: fetch_adapter(fetch),
      search: {Searxng, [endpoint: search_url]}
    )
  end

  defp build(_fetch, true, _search_url) do
    Error.single([:web, :search_url], :required, "is required when web search is enabled")
  end

  defp build(fetch, false, search_url) when is_nil(search_url) or is_binary(search_url) do
    Capability.new(policy: [fetch: fetch], fetch: fetch_adapter(fetch))
  end

  defp build(_fetch, false, _search_url) do
    Error.single([:web, :search_url], :invalid_value, "must be a URL or nil")
  end

  defp fetch_adapter(true) do
    {Mint, []}
  end

  defp fetch_adapter(false) do
    nil
  end
end
