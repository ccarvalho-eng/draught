defmodule Draught.CLI.Configuration.Source do
  @moduledoc """
  A validated configuration source with an explicit trust origin.

  Build sources with `Draught.CLI.Configuration.decode/2` and pass them to
  `Draught.CLI.Configuration.resolve/2`. Source internals are opaque;
  callers should not construct or modify the struct directly.
  """

  alias Draught.CLI.Configuration.Error
  alias Draught.CLI.Configuration.Profile
  alias Draught.CLI.Configuration.Value
  alias Draught.Provider.OpenAI.Configuration.Endpoint

  @allowed_keys MapSet.new(["profile", "model", "base_url", "web", "risk", "profiles"])
  @kinds [:defaults, :user, :project, :environment, :flags]

  @enforce_keys [:kind]
  defstruct [:kind, settings: %{}, profiles: %{}]

  @type kind :: :defaults | :user | :project | :environment | :flags
  @opaque t :: %__MODULE__{
            kind: kind(),
            settings: map(),
            profiles: map()
          }

  @doc "Validates a source origin against the closed precedence set."
  @spec validate_kind(term()) :: :ok | {:error, Error.t()}
  def validate_kind(kind) when kind in @kinds do
    :ok
  end

  def validate_kind(_kind) do
    Error.new(:defaults, [], :invalid_value, "configuration source is not supported")
  end

  @doc "Builds a validated source from decoded string-keyed attributes."
  @spec from_map(kind(), map()) :: Error.result(t())
  def from_map(kind, attributes) when is_map(attributes) do
    with :ok <- reject_unknown_keys(attributes, kind),
         {:ok, settings} <- settings(attributes, kind),
         {:ok, profiles} <- profiles(attributes, kind) do
      {:ok, %__MODULE__{kind: kind, settings: settings, profiles: profiles}}
    end
  end

  def from_map(kind, _attributes) do
    Error.new(kind, [], :invalid_type, "must contain a JSON object")
  end

  defp reject_unknown_keys(attributes, kind) do
    attributes
    |> Map.keys()
    |> Enum.all?(fn key -> MapSet.member?(@allowed_keys, key) end)
    |> unknown_keys_result(kind)
  end

  defp unknown_keys_result(true, _kind) do
    :ok
  end

  defp unknown_keys_result(false, kind) do
    Error.new(kind, [:unknown], :unknown_key, "configuration attribute is not supported")
  end

  defp settings(attributes, kind) do
    with {:ok, profile} <- optional_profile(attributes, kind),
         {:ok, model} <- optional_text(attributes, "model", kind, 256),
         {:ok, base_url} <- optional_base_url(attributes, kind),
         {:ok, web} <- optional_boolean(attributes, "web", kind),
         {:ok, risk} <- optional_risk(attributes, kind),
         :ok <- validate_project_authority(web, risk, kind) do
      values =
        %{}
        |> put_optional(:profile, profile)
        |> put_optional(:model, model)
        |> put_optional(:base_url, base_url)
        |> put_optional(:web, web)
        |> put_optional(:risk, risk)

      {:ok, values}
    end
  end

  defp optional_profile(attributes, :project) do
    attributes
    |> Map.has_key?("profile")
    |> restricted_profile_result()
  end

  defp optional_profile(attributes, kind) do
    optional_text(attributes, "profile", kind, 128)
  end

  defp optional_text(attributes, key, kind, maximum_bytes) do
    case Map.fetch(attributes, key) do
      {:ok, value} -> Value.text(value, kind, [known_key(key)], maximum_bytes)
      :error -> {:ok, :absent}
    end
  end

  defp optional_boolean(attributes, key, kind) do
    case Map.fetch(attributes, key) do
      {:ok, value} -> Value.boolean(value, kind, [known_key(key)])
      :error -> {:ok, :absent}
    end
  end

  defp optional_base_url(attributes, kind) when kind in [:environment, :flags] do
    case Map.fetch(attributes, "base_url") do
      {:ok, value} -> validate_base_url(value, kind)
      :error -> {:ok, :absent}
    end
  end

  defp optional_base_url(attributes, kind) do
    attributes
    |> Map.has_key?("base_url")
    |> restricted_base_url_result(kind)
  end

  defp validate_base_url(value, kind) do
    with {:ok, bounded} <- Value.text(value, kind, [:base_url], 2_048),
         {:ok, endpoint} <- Endpoint.new(bounded) do
      {:ok, endpoint}
    else
      {:error, %Error{}} = result -> result
      {:error, _error} -> Error.new(kind, [:base_url], :invalid_value, "must be a safe HTTP URL")
    end
  end

  defp optional_risk(attributes, kind) do
    case Map.fetch(attributes, "risk") do
      {:ok, value} -> Value.risk(value, kind)
      :error -> {:ok, :absent}
    end
  end

  defp validate_project_authority(:absent, :absent, :project) do
    :ok
  end

  defp validate_project_authority(false, :absent, :project) do
    :ok
  end

  defp validate_project_authority(:absent, :deny, :project) do
    :ok
  end

  defp validate_project_authority(false, :deny, :project) do
    :ok
  end

  defp validate_project_authority(_web, _risk, :project) do
    Error.new(
      :project,
      [:authority],
      :authority_denied,
      "project settings may only disable web and deny risky tools"
    )
  end

  defp validate_project_authority(_web, _risk, _kind) do
    :ok
  end

  defp profiles(attributes, kind) when kind in [:defaults, :user] do
    case Map.fetch(attributes, "profiles") do
      :error -> {:ok, %{}}
      {:ok, values} -> build_profiles(values, kind)
    end
  end

  defp profiles(attributes, kind) do
    attributes
    |> Map.has_key?("profiles")
    |> restricted_profiles_result(kind)
  end

  defp build_profiles(values, kind) when is_map(values) do
    values
    |> Enum.sort_by(fn {name, _attributes} -> name end)
    |> Enum.reduce_while({:ok, %{}}, fn {name, attributes}, {:ok, profiles} ->
      case Profile.new(name, attributes, kind) do
        {:ok, profile} -> {:cont, {:ok, Map.put(profiles, profile.name, profile)}}
        {:error, %Error{}} = result -> {:halt, result}
      end
    end)
  end

  defp build_profiles(_values, kind) do
    Error.new(kind, [:profiles], :invalid_type, "must be an object")
  end

  defp put_optional(values, _key, :absent) do
    values
  end

  defp put_optional(values, key, value) do
    Map.put(values, key, value)
  end

  defp restricted_profiles_result(false, _kind) do
    {:ok, %{}}
  end

  defp restricted_profiles_result(true, kind) do
    Error.new(
      kind,
      [:profiles],
      :authority_denied,
      "this source cannot define provider profiles"
    )
  end

  defp restricted_profile_result(false) do
    {:ok, :absent}
  end

  defp restricted_profile_result(true) do
    Error.new(
      :project,
      [:profile],
      :authority_denied,
      "project settings cannot select a provider profile"
    )
  end

  defp restricted_base_url_result(false, _kind) do
    {:ok, :absent}
  end

  defp restricted_base_url_result(true, kind) do
    Error.new(
      kind,
      [:base_url],
      :authority_denied,
      "endpoint overrides are allowed only from environment or command flags"
    )
  end

  defp known_key("profile"), do: :profile
  defp known_key("model"), do: :model
  defp known_key("base_url"), do: :base_url
  defp known_key("web"), do: :web
end
