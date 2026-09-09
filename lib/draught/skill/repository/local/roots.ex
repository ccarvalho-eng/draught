defmodule Draught.Skill.Repository.Local.Roots do
  @moduledoc """
  Resolves trusted workspace and user skill roots in precedence order.
  """

  @type origin :: Draught.Skill.Metadata.origin()
  @type root :: %{origin: origin(), path: String.t()}

  @doc "Returns unique roots from highest to lowest precedence."
  @spec list(String.t(), map(), term()) :: [root()]
  def list(workspace, environment, configuration)
      when is_binary(workspace) and is_map(environment) do
    [
      root(Path.join([workspace, ".draught", "skills"]), :workspace_draught),
      root(Path.join([workspace, ".agents", "skills"]), :workspace_agents),
      user_draught(environment),
      user_agents(environment),
      builtin(configuration)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(& &1.path)
  end

  defp user_draught(%{"XDG_CONFIG_HOME" => path}) when is_binary(path) and path != "" do
    root(Path.join([path, "draught", "skills"]), :user_draught)
  end

  defp user_draught(%{"HOME" => path}) when is_binary(path) and path != "" do
    root(Path.join([path, ".config", "draught", "skills"]), :user_draught)
  end

  defp user_draught(_environment) do
    nil
  end

  defp user_agents(%{"AGENTS_HOME" => path}) when is_binary(path) and path != "" do
    root(Path.join(path, "skills"), :user_agents)
  end

  defp user_agents(%{"HOME" => path}) when is_binary(path) and path != "" do
    root(Path.join([path, ".agents", "skills"]), :user_agents)
  end

  defp user_agents(_environment) do
    nil
  end

  defp builtin(%{builtin_root: path}) when is_binary(path) and path != "" do
    case Path.type(path) do
      :absolute -> root(path, :builtin)
      _type -> nil
    end
  end

  defp builtin(_configuration) do
    nil
  end

  defp root(path, origin) do
    %{origin: origin, path: path}
  end
end
