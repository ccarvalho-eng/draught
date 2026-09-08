defmodule Draught.CLI.Task.Named do
  @moduledoc """
  Dispatches creation or continuation of one persistent named CLI task.
  """

  alias Draught.CLI.Task.Named.Create
  alias Draught.CLI.Task.Named.Input
  alias Draught.CLI.Task.Named.Resume
  alias Draught.CLI.Task.Stream

  @doc "Executes one create or resume turn while holding the named session lease."
  @spec run(
          Draught.CLI.Session.Store.mode(),
          String.t(),
          String.t(),
          Draught.CLI.Configuration.t(),
          String.t(),
          map(),
          Draught.CLI.Task.Dependencies.t()
        ) :: Draught.CLI.Task.result()
  def run(operation, identifier, prompt, configuration, workspace, environment, dependencies)
      when operation in [:create, :resume] do
    input =
      Input.new(
        operation,
        identifier,
        prompt,
        configuration,
        workspace,
        environment,
        dependencies
      )

    {result, _stream} = execute(input, Stream.silent(), :complete)
    result
  end

  @doc "Creates one named session with an explicit canonical system instruction."
  @spec run(
          :create,
          String.t(),
          String.t(),
          Draught.CLI.Configuration.t(),
          String.t(),
          map(),
          Draught.CLI.Task.Dependencies.t(),
          String.t()
        ) :: Draught.CLI.Task.result()
  def run(
        :create,
        identifier,
        prompt,
        configuration,
        workspace,
        environment,
        dependencies,
        system_prompt
      )
      when is_binary(system_prompt) do
    input =
      :create
      |> Input.new(
        identifier,
        prompt,
        configuration,
        workspace,
        environment,
        dependencies
      )
      |> Input.put_system_prompt(system_prompt)

    {result, _stream} = execute(input, Stream.silent(), :complete)
    result
  end

  @doc "Executes a named turn while threading an ordered CLI stream observer."
  @spec run_observed(
          Draught.CLI.Session.Store.mode(),
          String.t(),
          String.t(),
          Draught.CLI.Configuration.t(),
          String.t(),
          map(),
          Draught.CLI.Task.Dependencies.t(),
          Stream.t()
        ) :: {Draught.CLI.Task.result(), Stream.t()}
  def run_observed(
        operation,
        identifier,
        prompt,
        configuration,
        workspace,
        environment,
        dependencies,
        stream
      )
      when operation in [:create, :resume] do
    input =
      Input.new(
        operation,
        identifier,
        prompt,
        configuration,
        workspace,
        environment,
        dependencies
      )

    execute(input, stream, :stream)
  end

  @doc "Creates one observed named session with an explicit canonical system instruction."
  @spec create_observed(
          String.t(),
          String.t(),
          Draught.CLI.Configuration.t(),
          String.t(),
          map(),
          Draught.CLI.Task.Dependencies.t(),
          Stream.t(),
          String.t()
        ) :: {Draught.CLI.Task.result(), Stream.t()}
  def create_observed(
        identifier,
        prompt,
        configuration,
        workspace,
        environment,
        dependencies,
        stream,
        system_prompt
      )
      when is_binary(system_prompt) do
    input =
      :create
      |> Input.new(
        identifier,
        prompt,
        configuration,
        workspace,
        environment,
        dependencies
      )
      |> Input.put_system_prompt(system_prompt)

    execute(input, stream, :stream)
  end

  defp execute(%Input{operation: operation} = input, stream, provider_mode) do
    operation
    |> executor()
    |> then(& &1.run_mode(input, stream, provider_mode))
  end

  defp executor(:create) do
    Create
  end

  defp executor(:resume) do
    Resume
  end
end
