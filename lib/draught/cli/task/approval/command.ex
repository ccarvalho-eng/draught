defmodule Draught.CLI.Task.Approval.Command do
  @moduledoc """
  Renders a validated process invocation as a safe shell-style approval line.

  The preview is display-only: execution continues to use the structured
  executable and argument list without invoking a shell.
  """

  alias Draught.CLI.Output.Sanitizer
  alias Draught.Tool.Builtin.RunCommand.Input

  @line_breaks ~r/[\n\r\x{2028}\x{2029}]/u
  @safe_token ~r/\A[A-Za-z0-9_@%+=:,\.\/-]+\z/u

  @doc "Renders a complete command preview, or marks unsafe input unavailable."
  @spec render(String.t()) :: {:ok, iodata()} | {:error, :unavailable}
  def render(preview) when is_binary(preview) do
    with {:ok, operation} when is_map(operation) <- Jason.decode(preview),
         {:ok, input} <- Input.new(operation),
         true <- terminal_safe?(input) do
      tokens = [input.executable | input.arguments]

      command =
        tokens
        |> Enum.map(&quote_token/1)
        |> Enum.intersperse(" ")

      {:ok, ["[command] ", command, "\n"]}
    else
      _unavailable -> {:error, :unavailable}
    end
  end

  def render(_preview) do
    {:error, :unavailable}
  end

  defp terminal_safe?(input) do
    input
    |> then(&[&1.executable | &1.arguments])
    |> Enum.all?(&terminal_safe_token?/1)
  end

  defp terminal_safe_token?(token) do
    Sanitizer.text(token) == token and not Regex.match?(@line_breaks, token)
  end

  defp quote_token("") do
    "''"
  end

  defp quote_token(token) do
    token
    |> then(&Regex.match?(@safe_token, &1))
    |> quote_token(token)
  end

  defp quote_token(true, token) do
    token
  end

  defp quote_token(false, token) do
    ["'", String.replace(token, "'", "'\"'\"'"), "'"]
  end
end
