defmodule Draught.CLI.Task.Web.Setting do
  @moduledoc """
  Projects resolved CLI configuration into the trusted web-capability setting.

  Task preparation and read-only inspection consume the same projection so the
  displayed capability state cannot drift from the execution boundary.
  """

  alias Draught.CLI.Configuration
  alias Draught.CLI.Task.Preparation.Web

  @doc "Returns the fetch, search, and endpoint values used to construct web capability."
  @spec from_configuration(Configuration.t()) :: Web.setting()
  def from_configuration(%Configuration{} = configuration) do
    %{
      fetch: configuration.web,
      search: configuration.web_search,
      search_url: configuration.web_search_url
    }
  end
end
