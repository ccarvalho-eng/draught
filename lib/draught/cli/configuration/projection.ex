defmodule Draught.CLI.Configuration.Projection do
  @moduledoc """
  Projects a selected profile and invocation overrides into runtime CLI configuration.
  """

  alias Draught.CLI.Configuration
  alias Draught.CLI.Configuration.Credential

  @doc "Projects resolved configuration without secrets, header values, or endpoint paths."
  @spec safe(Configuration.t()) :: map()
  def safe(%Configuration{} = configuration) do
    %{
      "profile" => configuration.profile,
      "provider" => provider(configuration.provider),
      "model" => configuration.model,
      "base_url" => safe_endpoint(configuration.base_url),
      "web" => configuration.web,
      "web_search" => configuration.web_search,
      "web_search_url" => safe_optional_endpoint(configuration.web_search_url),
      "risk" => Atom.to_string(configuration.risk),
      "credential" => credential_status(configuration.credential),
      "header_names" => header_names(configuration.headers),
      "sources" => sources(configuration.origins)
    }
  end

  defp provider(:ollama) do
    "ollama"
  end

  defp provider(:openai_compatible) do
    "openai-compatible"
  end

  defp credential_status(nil) do
    "not_configured"
  end

  defp credential_status(%Credential{}) do
    "configured"
  end

  defp sources(origins) do
    Map.new(origins, fn {key, source} -> {Atom.to_string(key), Atom.to_string(source)} end)
  end

  defp header_names(headers) do
    headers
    |> Map.keys()
    |> Enum.sort()
  end

  defp safe_endpoint(base_url) do
    uri = URI.parse(base_url)
    URI.to_string(%{uri | path: nil, query: nil, fragment: nil, userinfo: nil})
  end

  defp safe_optional_endpoint(nil) do
    nil
  end

  defp safe_optional_endpoint(url) do
    safe_endpoint(url)
  end
end
