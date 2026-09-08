defmodule Draught.CLI.Configuration.User.Path do
  @moduledoc """
  Resolves the single user configuration path from an immutable environment snapshot.
  """

  @doc "Returns the user configuration path when an XDG or home root is available."
  @spec configuration(map()) :: String.t() | nil
  def configuration(%{"XDG_CONFIG_HOME" => root}) when is_binary(root) and root != "" do
    Path.join([root, "draught", "config.json"])
  end

  def configuration(%{"HOME" => home}) when is_binary(home) and home != "" do
    Path.join([home, ".config", "draught", "config.json"])
  end

  def configuration(_environment) do
    nil
  end
end
