defmodule Draught.CLI.Task.Named do
  @moduledoc """
  Dispatches creation or continuation of one persistent named CLI task.
  """

  alias Draught.CLI.Task.Named.Create
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
    executor = executor(operation)

    {result, _stream} =
      executor.run_mode(
        identifier,
        prompt,
        configuration,
        workspace,
        environment,
        dependencies,
        Stream.silent(),
        :complete
      )

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
    executor = executor(operation)

    executor.run_mode(
      identifier,
      prompt,
      configuration,
      workspace,
      environment,
      dependencies,
      stream,
      :stream
    )
  end

  defp executor(:create) do
    Create
  end

  defp executor(:resume) do
    Resume
  end
end
