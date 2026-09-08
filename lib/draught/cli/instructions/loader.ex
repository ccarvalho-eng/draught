defmodule Draught.CLI.Instructions.Loader do
  @moduledoc """
  Reads bounded user and workspace AGENTS.md files through the CLI system boundary.

  The loader reads exactly one user location and the selected workspace root. It
  does not search ancestors, expand includes, interpolate values, or interpret
  guidance as configuration.
  """

  alias Draught.CLI.Instructions.Bundle
  alias Draught.CLI.Instructions.Failure
  alias Draught.Error.Normalized

  @maximum_bytes 32_768

  @doc "Loads the ordered guidance bundle for a selected workspace."
  @spec load(String.t(), {module(), term()}) ::
          {:ok, Bundle.t()} | {:error, Normalized.t()}
  def load(workspace, {system, system_configuration})
      when is_binary(workspace) and byte_size(workspace) > 0 and is_atom(system) do
    environment = system.environment(system_configuration)

    with {:ok, user} <-
           read_optional(
             :user,
             user_path(environment),
             system,
             system_configuration
           ),
         {:ok, project} <-
           read_optional(
             :workspace,
             workspace_path(workspace),
             system,
             system_configuration
           ) do
      Bundle.new(user ++ project)
    end
  end

  def load(_workspace, _system) do
    {:error, Failure.invalid()}
  end

  defp read_optional(_scope, nil, _system, _system_configuration) do
    {:ok, []}
  end

  defp read_optional(scope, path, system, system_configuration) do
    case system.read_file(path, @maximum_bytes, system_configuration) do
      {:ok, content} -> {:ok, [{scope, content}]}
      :missing -> {:ok, []}
      {:error, :too_large} -> {:error, Failure.too_large()}
      {:error, :unsafe_file} -> {:error, Failure.unsafe()}
      {:error, :io} -> {:error, Failure.unavailable()}
    end
  end

  defp user_path(%{"XDG_CONFIG_HOME" => root}) when is_binary(root) and root != "" do
    Path.join([root, "draught", "AGENTS.md"])
  end

  defp user_path(%{"HOME" => home}) when is_binary(home) and home != "" do
    Path.join([home, ".config", "draught", "AGENTS.md"])
  end

  defp user_path(_environment) do
    nil
  end

  defp workspace_path(workspace) do
    Path.join(workspace, "AGENTS.md")
  end
end
