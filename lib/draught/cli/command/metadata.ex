defmodule Draught.CLI.Command.Metadata do
  @moduledoc """
  Structured help and version values that contain no terminal formatting.
  """

  alias Draught.CLI.Command.Specification

  @type help_metadata :: %{
          name: String.t(),
          usage: [String.t()],
          commands: [Specification.command()],
          options: [Specification.option()],
          examples: [String.t()]
        }

  @type version_metadata :: %{name: String.t(), version: String.t()}

  @doc "Returns renderer-neutral command help data."
  @spec help() :: help_metadata()
  def help do
    %{
      name: "draught",
      usage: ["draught [OPTIONS] [TASK]", "draught COMMAND [OPTIONS]"],
      commands: Specification.commands(),
      options: Specification.options(),
      examples: Specification.examples()
    }
  end

  @doc "Returns the loaded Draught application version."
  @spec version() :: version_metadata()
  def version do
    %{name: "draught", version: application_version()}
  end

  defp application_version do
    :draught
    |> Application.spec(:vsn)
    |> version_value()
  end

  defp version_value(nil) do
    "unknown"
  end

  defp version_value(value) do
    to_string(value)
  end
end
