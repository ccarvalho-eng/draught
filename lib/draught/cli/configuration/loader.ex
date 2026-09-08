defmodule Draught.CLI.Configuration.Loader do
  @moduledoc """
  Loads bounded CLI configuration sources and resolves them with fixed precedence.
  """

  alias Draught.CLI.Command.Invocation
  alias Draught.CLI.Configuration
  alias Draught.CLI.Configuration.Error
  alias Draught.CLI.Configuration.Source

  @maximum_file_bytes 65_536
  @environment_keys %{
    "DRAUGHT_BASE_URL" => "base_url",
    "DRAUGHT_MODEL" => "model",
    "DRAUGHT_PROVIDER" => "profile",
    "DRAUGHT_RISK" => "risk",
    "DRAUGHT_WEB" => "web",
    "DRAUGHT_WEB_SEARCH" => "web_search",
    "DRAUGHT_WEB_SEARCH_URL" => "web_search_url"
  }
  @defaults %{
    "profile" => "ollama",
    "web" => false,
    "risk" => "ask",
    "profiles" => %{
      "ollama" => %{
        "provider" => "ollama",
        "base_url" => "http://localhost:11434"
      }
    }
  }

  @doc "Loads configuration for an invocation through an explicit system boundary."
  @spec load(Invocation.t(), {module(), term()}) ::
          {:ok, Configuration.t(), String.t()} | {:error, Error.t()}
  def load(%Invocation{} = invocation, {system, system_configuration}) when is_atom(system) do
    environment = system.environment(system_configuration)

    load_with_environment(invocation, system, system_configuration, environment)
  end

  defp load_with_environment(invocation, system, system_configuration, environment) do
    with {:ok, cwd} <- current_directory(system, system_configuration),
         {:ok, sources} <-
           sources(invocation, cwd, environment, system, system_configuration),
         {:ok, configuration} <- Configuration.resolve(sources, environment) do
      {:ok, configuration, cwd}
    end
  end

  defp sources(invocation, cwd, environment, system, system_configuration) do
    with {:ok, defaults} <- Source.from_map(:defaults, @defaults),
         {:ok, user} <-
           optional_source(
             :user,
             Draught.CLI.Configuration.User.Path.configuration(environment),
             system,
             system_configuration
           ),
         {:ok, project} <-
           optional_source(:project, project_path(cwd), system, system_configuration),
         {:ok, environment_source} <- environment_source(environment),
         {:ok, flags} <- flags_source(invocation) do
      {:ok, [defaults, user, project, environment_source, flags]}
    end
  end

  defp current_directory(system, system_configuration) do
    case system.cwd(system_configuration) do
      {:ok, cwd} when is_binary(cwd) and byte_size(cwd) > 0 -> {:ok, cwd}
      _result -> source_error(:project, "current workspace is unavailable")
    end
  end

  defp optional_source(kind, nil, _system, _system_configuration) do
    Source.from_map(kind, %{})
  end

  defp optional_source(kind, path, system, system_configuration) do
    case system.read_file(path, @maximum_file_bytes, system_configuration) do
      {:ok, content} -> Configuration.decode(kind, content)
      :missing -> Source.from_map(kind, %{})
      {:error, :too_large} -> Error.new(kind, [], :too_large, "configuration file is too large")
      {:error, :unsafe_file} -> source_error(kind, "configuration file is not a regular file")
      {:error, :io} -> source_error(kind, "configuration file cannot be read")
    end
  end

  defp environment_source(environment) when is_map(environment) do
    environment
    |> Map.take(Map.keys(@environment_keys))
    |> Enum.reduce_while({:ok, %{}}, &environment_setting/2)
    |> source_result(:environment)
  end

  defp environment_setting({name, value}, {:ok, settings}) do
    key = Map.fetch!(@environment_keys, name)

    case environment_value(key, value) do
      {:ok, normalized} ->
        {:cont, {:ok, Map.put(settings, key, normalized)}}

      :error ->
        {:halt,
         Error.new(
           :environment,
           [environment_path(key)],
           :invalid_value,
           environment_message(key)
         )}
    end
  end

  defp environment_value(key, "true") when key in ["web", "web_search"] do
    {:ok, true}
  end

  defp environment_value(key, "false") when key in ["web", "web_search"] do
    {:ok, false}
  end

  defp environment_value(key, _value) when key in ["web", "web_search"] do
    :error
  end

  defp environment_value(_key, value) when is_binary(value) do
    {:ok, value}
  end

  defp environment_value(_key, _value) do
    :error
  end

  defp flags_source(%Invocation{} = invocation) do
    settings =
      %{}
      |> put_present("profile", invocation.provider)
      |> put_present("model", invocation.model)
      |> put_present("base_url", invocation.base_url)
      |> put_present("web_search_url", invocation.web_search_url)
      |> put_web(invocation.web)
      |> put_boolean("web_search", invocation.web_search)

    Source.from_map(:flags, settings)
  end

  defp put_present(settings, _key, nil) do
    settings
  end

  defp put_present(settings, key, value) do
    Map.put(settings, key, value)
  end

  defp put_web(settings, :inherit) do
    settings
  end

  defp put_web(settings, :enabled) do
    Map.put(settings, "web", true)
  end

  defp put_web(settings, :disabled) do
    Map.put(settings, "web", false)
  end

  defp put_boolean(settings, _key, :inherit) do
    settings
  end

  defp put_boolean(settings, key, :enabled) do
    Map.put(settings, key, true)
  end

  defp put_boolean(settings, key, :disabled) do
    Map.put(settings, key, false)
  end

  defp source_result({:ok, settings}, kind) do
    Source.from_map(kind, settings)
  end

  defp source_result({:error, %Error{}} = result, _kind) do
    result
  end

  defp project_path(cwd) do
    Path.join([cwd, ".draught", "config.json"])
  end

  defp environment_path("base_url"), do: :base_url
  defp environment_path("model"), do: :model
  defp environment_path("profile"), do: :profile
  defp environment_path("risk"), do: :risk
  defp environment_path("web"), do: :web
  defp environment_path("web_search"), do: :web_search
  defp environment_path("web_search_url"), do: :web_search_url

  defp environment_message(key) when key in ["web", "web_search"] do
    "must be true or false"
  end

  defp environment_message(_key) do
    "contains an invalid value"
  end

  defp source_error(kind, message) do
    Error.new(kind, [], :source_unavailable, message)
  end
end
