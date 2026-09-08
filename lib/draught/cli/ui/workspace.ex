defmodule Draught.CLI.UI.Workspace do
  @moduledoc """
  Produces a bounded, display-only workspace path for terminal views.

  Paths inside the current user's home use a tilde prefix. The canonical
  workspace retained by session and tool boundaries is not changed.
  """

  alias Draught.CLI.UI.SafeLine

  @maximum_bytes 2_048

  @doc "Shortens a sanitized workspace path against the supplied user home."
  @spec display(String.t(), String.t() | nil) :: String.t()
  def display(path, user_home \\ System.user_home()) when is_binary(path) do
    safe_path = SafeLine.text(path, @maximum_bytes)
    safe_home = safe_home(user_home)

    compact(safe_path, safe_home)
  end

  defp compact(path, nil) do
    path
  end

  defp compact(path, "/") do
    path
  end

  defp compact(path, path) do
    "~"
  end

  defp compact(path, user_home) do
    prefix = user_home <> "/"

    path
    |> String.starts_with?(prefix)
    |> compact_prefix(path, user_home)
  end

  defp compact_prefix(true, path, user_home) do
    String.replace_prefix(path, user_home, "~")
  end

  defp compact_prefix(false, path, _user_home) do
    path
  end

  defp safe_home(user_home) when is_binary(user_home) do
    user_home
    |> SafeLine.text(@maximum_bytes)
    |> String.trim_trailing("/")
    |> present_home()
  end

  defp safe_home(_user_home) do
    nil
  end

  defp present_home("") do
    nil
  end

  defp present_home(user_home) do
    user_home
  end
end
