defmodule Draught.CLI.Command.Intent do
  @moduledoc false

  alias Draught.CLI.Command.Error
  alias Draught.CLI.Command.Invocation
  alias Draught.CLI.Command.Options
  alias Draught.CLI.Command.Specification

  @operational_options [:provider, :model, :base_url, :session, :resume, :web, :diagnostics]

  @doc "Resolves named commands and root task text into one invocation."
  @spec resolve([String.t()], [String.t()], Options.t()) ::
          {:ok, Invocation.t()} | {:error, Error.t()}
  def resolve(positionals, literal, %Options{} = options) do
    with {:ok, command, prompt} <- command(positionals, literal, options),
         :ok <- command_options(command, options) do
      {:ok, invocation(command, prompt, options)}
    end
  end

  defp command(positionals, literal, %Options{help: true}) do
    metadata_command(:help, positionals, literal)
  end

  defp command(positionals, literal, %Options{version: true}) do
    metadata_command(:version, positionals, literal)
  end

  defp command([], [], %Options{}) do
    {:ok, :interactive, nil}
  end

  defp command([], literal, %Options{}) do
    task(literal)
  end

  defp command(["interactive" | rest], literal, %Options{}) do
    named_command(:interactive, rest, literal)
  end

  defp command(["doctor" | rest], literal, %Options{}) do
    named_command(:doctor, rest, literal)
  end

  defp command(["help" | rest], literal, %Options{}) do
    named_command(:help, rest, literal)
  end

  defp command(["version" | rest], literal, %Options{}) do
    named_command(:version, rest, literal)
  end

  defp command(positionals, literal, %Options{}) do
    task(positionals ++ literal)
  end

  defp metadata_command(command, [], []) do
    {:ok, command, nil}
  end

  defp metadata_command(_command, _positionals, _literal) do
    error(
      :conflicting_options,
      "Help and version options cannot be combined with a command or task"
    )
  end

  defp named_command(command, [], []) do
    {:ok, command, nil}
  end

  defp named_command(_command, _rest, _literal) do
    error(:unexpected_argument, "Named commands do not accept positional arguments")
  end

  defp task(arguments) do
    maximum = Specification.limits().prompt_bytes
    size = prompt_size(arguments)
    task(size, maximum, arguments)
  end

  defp prompt_size([]) do
    0
  end

  defp prompt_size(arguments) do
    content_bytes = Enum.sum_by(arguments, &byte_size/1)
    content_bytes + Enum.count(arguments) - 1
  end

  defp task(0, _maximum, _arguments) do
    error(:invalid_argument, "Task prompt must not be empty")
  end

  defp task(size, maximum, arguments) when size <= maximum do
    {:ok, :task, Enum.join(arguments, " ")}
  end

  defp task(_size, _maximum, _arguments) do
    error(:prompt_too_large, "Task prompt exceeds the byte limit")
  end

  defp command_options(command, options) when command in [:help, :version] do
    conflict = Enum.any?(@operational_options, &Options.present?(options, &1))
    valid_result(not conflict, "The command does not accept operational options")
  end

  defp command_options(:doctor, %Options{} = options) do
    conflict = not is_nil(options.session) or not is_nil(options.resume)
    valid_result(not conflict, "Doctor does not accept session options")
  end

  defp command_options(_command, %Options{}) do
    :ok
  end

  defp invocation(command, prompt, options) do
    %Invocation{
      command: command,
      prompt: prompt,
      provider: options.provider,
      model: options.model,
      base_url: options.base_url,
      session: options.session,
      resume: options.resume,
      web: options.web,
      output: options.output,
      color: options.color,
      diagnostics: options.diagnostics
    }
  end

  defp valid_result(true, _message) do
    :ok
  end

  defp valid_result(false, message) do
    error(:conflicting_options, message)
  end

  defp error(code, message) do
    {:error, Error.new(code, message)}
  end
end
