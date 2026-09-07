defmodule Draught.CLI.Configuration.Resolver do
  @moduledoc false

  alias Draught.CLI.Configuration
  alias Draught.CLI.Configuration.Credential
  alias Draught.CLI.Configuration.Error
  alias Draught.CLI.Configuration.Profile
  alias Draught.CLI.Configuration.Source

  @precedence [:defaults, :user, :project, :environment, :flags]

  @doc "Resolves validated sources with fixed precedence and separate authority checks."
  @spec resolve([Source.t()], map()) :: Error.result(Configuration.t())
  def resolve(sources, environment) when is_list(sources) and is_map(environment) do
    with {:ok, indexed} <- index_sources(sources) do
      resolve_indexed(indexed, environment)
    end
  end

  def resolve(_sources, _environment) do
    Error.new(
      :defaults,
      [],
      :invalid_type,
      "sources must be a list and environment must be a map"
    )
  end

  defp resolve_indexed(indexed, environment) do
    {settings, origins, profiles} = merge_sources(indexed)

    with {:ok, profile_name} <- selected_profile(settings),
         {:ok, profile} <- fetch_profile(profile_name, profiles),
         :ok <- profile_authority(profile, origins),
         {:ok, credential} <- credential(profile, environment),
         :ok <- endpoint_override(profile, settings, origins) do
      {:ok, build(settings, origins, profile, credential)}
    end
  end

  defp index_sources(sources) do
    Enum.reduce_while(sources, {:ok, %{}}, fn source, {:ok, indexed} ->
      index_source(source, indexed)
    end)
  end

  defp index_source(%Source{kind: kind} = source, indexed) when kind in @precedence do
    indexed
    |> Map.has_key?(kind)
    |> source_index_result(source, indexed)
  end

  defp index_source(_source, _indexed) do
    {:halt, Error.new(:defaults, [], :invalid_type, "contains an invalid source")}
  end

  defp merge_sources(indexed) do
    Enum.reduce(@precedence, {%{}, %{}, %{}}, fn kind, accumulator ->
      merge_source(Map.get(indexed, kind), accumulator)
    end)
  end

  defp merge_source(nil, accumulator) do
    accumulator
  end

  defp merge_source(
         %Source{kind: kind, settings: settings, profiles: profiles},
         {values, origins, known}
       ) do
    updated_origins =
      settings
      |> Map.keys()
      |> Enum.reduce(origins, fn key, acc ->
        Map.put(acc, key, kind)
      end)

    {Map.merge(values, settings), updated_origins, Map.merge(known, profiles)}
  end

  defp selected_profile(settings) do
    case Map.fetch(settings, :profile) do
      {:ok, profile} -> {:ok, profile}
      :error -> Error.new(:defaults, [:profile], :required, "a provider profile is required")
    end
  end

  defp fetch_profile(name, profiles) do
    case Map.fetch(profiles, name) do
      {:ok, profile} ->
        {:ok, profile}

      :error ->
        Error.new(:defaults, [:profile], :unknown_profile, "selected profile is not defined")
    end
  end

  defp credential(%Profile{credential_env: nil}, _environment) do
    {:ok, nil}
  end

  defp credential(%Profile{name: name, credential_env: variable}, environment) do
    case Map.fetch(environment, variable) do
      {:ok, value} ->
        Credential.new(name, value)

      :error ->
        Error.new(
          :environment,
          [:credential],
          :missing_credential,
          "selected profile credential is unavailable"
        )
    end
  end

  defp profile_authority(%Profile{credential_env: nil}, _origins) do
    :ok
  end

  defp profile_authority(%Profile{}, %{profile: :project}) do
    Error.new(
      :project,
      [:profile],
      :authority_denied,
      "project settings cannot activate a credential-bound profile"
    )
  end

  defp profile_authority(%Profile{}, _origins) do
    :ok
  end

  defp build(settings, origins, profile, credential) do
    profile_origins =
      origins
      |> Map.put(:provider, profile.source)
      |> Map.put_new(:base_url, profile.source)
      |> Map.put(:headers, profile.source)
      |> put_credential_origin(credential)

    %Configuration{
      profile: profile.name,
      provider: profile.provider,
      base_url: Map.get(settings, :base_url, profile.base_url),
      model: Map.get(settings, :model),
      credential: credential,
      headers: profile.headers,
      web: Map.get(settings, :web, false),
      risk: Map.get(settings, :risk, :ask),
      origins: profile_origins
    }
  end

  defp put_credential_origin(origins, nil) do
    origins
  end

  defp put_credential_origin(origins, %Credential{}) do
    Map.put(origins, :credential, :environment)
  end

  defp endpoint_override(%Profile{credential_env: nil}, _settings, _origins) do
    :ok
  end

  defp endpoint_override(%Profile{}, settings, origins) do
    settings
    |> Map.has_key?(:base_url)
    |> endpoint_override_result(origins)
  end

  defp endpoint_override_result(false, _origins) do
    :ok
  end

  defp endpoint_override_result(true, origins) do
    source = Map.fetch!(origins, :base_url)

    Error.new(
      source,
      [:base_url],
      :authority_denied,
      "credential-bound profiles do not accept endpoint overrides"
    )
  end

  defp source_index_result(true, %Source{kind: kind}, _indexed) do
    {:halt, Error.new(kind, [], :duplicate_source, "source was provided more than once")}
  end

  defp source_index_result(false, %Source{kind: kind} = source, indexed) do
    {:cont, {:ok, Map.put(indexed, kind, source)}}
  end
end
