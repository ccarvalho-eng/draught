defmodule Draught.CLI.Interactive.Input do
  @moduledoc """
  Parses bounded interactive input into terminal-independent shell actions.

  Slash commands, direct shell requests, and file searches remain explicit
  actions so they cannot be forwarded to a provider as ordinary prompts.
  """

  alias Draught.CLI.Interactive.Command.Catalog
  alias Draught.CLI.Interactive.Command.Catalog.Entry

  @maximum_bytes 65_536

  @type command ::
          :archive
          | :compact
          | :context
          | :details
          | :diff
          | :doctor
          | :exit
          | :help
          | :model
          | :new
          | :palette
          | :permissions
          | :provider
          | :rename
          | :restore
          | :resume
          | :review
          | :sessions
          | :skill
          | :skills
          | :status
          | :tools
          | :web
  @type action ::
          :empty
          | {:command, command(), String.t() | nil}
          | {:file, String.t() | nil}
          | {:prompt, String.t()}
          | {:shell, String.t()}
  @type error ::
          :argument_required
          | :input_too_large
          | :invalid_input
          | :unexpected_argument
          | :unknown_command

  @doc "Returns the maximum accepted byte size for one interactive input record."
  @spec maximum_bytes() :: pos_integer()
  def maximum_bytes do
    @maximum_bytes
  end

  @doc "Parses one input record without performing terminal or provider effects."
  @spec parse(term()) :: {:ok, action()} | {:error, error()}
  def parse(input) when is_binary(input) and byte_size(input) <= @maximum_bytes do
    input
    |> valid_input?()
    |> parse_valid(input)
  end

  def parse(input) when is_binary(input) do
    {:error, :input_too_large}
  end

  def parse(_input) do
    {:error, :invalid_input}
  end

  defp valid_input?(input) do
    String.valid?(input) and not String.contains?(input, <<0>>)
  end

  defp parse_valid(false, _input) do
    {:error, :invalid_input}
  end

  defp parse_valid(true, input) do
    input
    |> String.trim()
    |> classify()
  end

  defp classify("") do
    {:ok, :empty}
  end

  defp classify("/") do
    {:ok, {:command, :palette, nil}}
  end

  defp classify("!" <> command) do
    required_action(:shell, command)
  end

  defp classify("@" <> query) do
    optional_action(:file, query)
  end

  defp classify("/" <> command) do
    parse_command(command)
  end

  defp classify(prompt) do
    {:ok, {:prompt, prompt}}
  end

  defp parse_command(input) do
    case String.split(input, ~r/\s+/, parts: 2, trim: true) do
      [name] -> command(name, nil)
      [name, argument] -> command(name, argument)
      [] -> {:ok, {:command, :palette, nil}}
    end
  end

  defp command(name, argument) do
    name
    |> command_name()
    |> command_result(argument)
  end

  defp command_name(name) do
    Catalog.find(name)
  end

  defp command_result(nil, _argument) do
    {:error, :unknown_command}
  end

  defp command_result(%Entry{argument: :optional, name: name}, nil) do
    {:ok, {:command, name, nil}}
  end

  defp command_result(%Entry{argument: :required}, nil) do
    {:error, :argument_required}
  end

  defp command_result(%Entry{argument: :none, name: name}, nil) do
    {:ok, {:command, name, nil}}
  end

  defp command_result(%Entry{argument: argument, name: name}, value)
       when argument in [:optional, :required] do
    {:ok, {:command, name, value}}
  end

  defp command_result(%Entry{argument: :none}, _argument) do
    {:error, :unexpected_argument}
  end

  defp required_action(kind, value) do
    case String.trim(value) do
      "" -> {:error, :argument_required}
      trimmed -> {:ok, {kind, trimmed}}
    end
  end

  defp optional_action(kind, value) do
    case String.trim(value) do
      "" -> {:ok, {kind, nil}}
      trimmed -> {:ok, {kind, trimmed}}
    end
  end
end
