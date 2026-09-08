defmodule Draught.CLI.Configuration.User.Preference do
  @moduledoc """
  Persists explicit interactive preferences without replacing unrelated user settings.

  Existing configuration is decoded through the public closed schema before one
  preference is changed. Publication remains behind the CLI system boundary.
  """

  alias Draught.CLI.Configuration
  alias Draught.CLI.Configuration.Error
  alias Draught.CLI.Configuration.Source

  @maximum_file_bytes 65_536

  @type error :: :not_saved | :outcome_unknown

  @doc "Atomically saves a validated model as the user configuration default."
  @spec save_model(term(), {module(), term()}) :: :ok | {:error, error()}
  def save_model(model, {system, system_configuration}) when is_atom(system) do
    environment = system.environment(system_configuration)

    result =
      with {:ok, path} <- path(environment),
           {:ok, _source} <- Source.from_map(:user, %{"model" => model}),
           {:ok, attributes} <- attributes(path, system, system_configuration),
           {:ok, content} <- encode(Map.put(attributes, "model", model)) do
        write(path, content, system, system_configuration)
      end

    preference_result(result)
  end

  defp path(environment) do
    case Draught.CLI.Configuration.User.Path.configuration(environment) do
      nil -> source_error("user configuration location is unavailable")
      path -> {:ok, path}
    end
  end

  defp attributes(path, system, system_configuration) do
    case system.read_file(path, @maximum_file_bytes, system_configuration) do
      {:ok, content} -> decode(content)
      :missing -> {:ok, %{}}
      {:error, :too_large} -> Error.new(:user, [], :too_large, "configuration file is too large")
      {:error, :unsafe_file} -> source_error("configuration file is not a regular file")
      {:error, :io} -> source_error("configuration file cannot be read")
    end
  end

  defp decode(content) do
    with {:ok, _source} <- Configuration.decode(:user, content),
         {:ok, attributes} <- Jason.decode(content) do
      {:ok, attributes}
    else
      {:error, %Error{}} = result -> result
      {:error, _error} -> Error.new(:user, [], :invalid_json, "must contain valid JSON")
    end
  end

  defp encode(attributes) do
    case Jason.encode(attributes, pretty: true) do
      {:ok, content} when byte_size(content) < @maximum_file_bytes -> {:ok, content <> "\n"}
      {:ok, _content} -> Error.new(:user, [], :too_large, "configuration file is too large")
      {:error, _error} -> source_error("configuration file cannot be encoded")
    end
  end

  defp write(path, content, system, system_configuration) do
    case system.write_file(path, content, system_configuration) do
      :ok ->
        :ok

      {:error, :unsafe_file} ->
        source_error("configuration file is not a regular file")

      {:error, :publication_unknown} ->
        Error.new(:user, [], :publication_unknown, "configuration update outcome is unknown")

      {:error, :io} ->
        source_error("configuration file cannot be written")
    end
  end

  defp source_error(message) do
    Error.new(:user, [], :source_unavailable, message)
  end

  defp preference_result(:ok) do
    :ok
  end

  defp preference_result({:error, %Error{code: :publication_unknown}}) do
    {:error, :outcome_unknown}
  end

  defp preference_result({:error, %Error{}}) do
    {:error, :not_saved}
  end
end
