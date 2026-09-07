defmodule Draught.Tool.Builtin.RunCommand.Environment do
  @moduledoc """
  Builds the controlled environment used for command execution.

  Inherited variables are removed, a fixed set of process variables is
  supplied, and the executable search path is returned for separate resolution.
  """

  @default_path "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"

  @type entry :: {charlist(), charlist() | false}

  @doc "Builds a scrubbed child environment and its executable search path."
  @spec build(String.t(), map()) :: {:ok, [entry()], String.t()} | {:error, :invalid_environment}
  def build(workspace, configuration) when is_binary(workspace) and is_map(configuration) do
    path = Map.get(configuration, :path, System.get_env("PATH", @default_path))
    build_result(valid_path?(path), workspace, path)
  end

  defp entries(workspace, path) do
    current =
      System.get_env()
      |> Map.keys()
      |> Map.new(&{&1, false})

    controlled = %{
      "GIT_CONFIG_GLOBAL" => "/dev/null",
      "GIT_CONFIG_NOSYSTEM" => "1",
      "GIT_TERMINAL_PROMPT" => "0",
      "HOME" => workspace,
      "LANG" => "C.UTF-8",
      "LC_ALL" => "C.UTF-8",
      "NO_COLOR" => "1",
      "PATH" => path,
      "TMPDIR" => "/tmp"
    }

    current
    |> Map.merge(controlled)
    |> Enum.map(&entry/1)
  end

  defp entry({name, false}) do
    {String.to_charlist(name), false}
  end

  defp entry({name, value}) do
    {String.to_charlist(name), String.to_charlist(value)}
  end

  defp valid_path?(path) when is_binary(path) and byte_size(path) > 0 do
    :binary.match(path, <<0>>) == :nomatch
  end

  defp valid_path?(_path) do
    false
  end

  defp build_result(true, workspace, path) do
    {:ok, entries(workspace, path), path}
  end

  defp build_result(false, _workspace, _path) do
    {:error, :invalid_environment}
  end
end
