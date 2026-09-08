defmodule Draught.CLI.Task.Named.Input do
  @moduledoc """
  Groups the immutable inputs for one named CLI task operation.

  The system instruction is relevant only when creating a session. Resume
  reconstructs its instruction from durable conversation history.
  """

  alias Draught.CLI.Configuration
  alias Draught.CLI.Task.Dependencies
  alias Draught.CLI.Task.Preparation

  @enforce_keys [
    :configuration,
    :dependencies,
    :environment,
    :identifier,
    :operation,
    :prompt,
    :system_prompt,
    :workspace
  ]
  defstruct [
    :configuration,
    :dependencies,
    :environment,
    :identifier,
    :operation,
    :prompt,
    :system_prompt,
    :workspace
  ]

  @type t :: %__MODULE__{
          configuration: Configuration.t(),
          dependencies: Dependencies.t(),
          environment: map(),
          identifier: String.t(),
          operation: :create | :resume,
          prompt: String.t(),
          system_prompt: String.t(),
          workspace: String.t()
        }

  @doc "Builds named task input with the built-in system instruction."
  @spec new(
          :create | :resume,
          String.t(),
          String.t(),
          Configuration.t(),
          String.t(),
          map(),
          Dependencies.t()
        ) :: t()
  def new(
        operation,
        identifier,
        prompt,
        %Configuration{} = configuration,
        workspace,
        environment,
        %Dependencies{} = dependencies
      )
      when operation in [:create, :resume] and is_binary(identifier) and is_binary(prompt) and
             is_binary(workspace) and is_map(environment) do
    %__MODULE__{
      configuration: configuration,
      dependencies: dependencies,
      environment: environment,
      identifier: identifier,
      operation: operation,
      prompt: prompt,
      system_prompt: Preparation.system_prompt(),
      workspace: workspace
    }
  end

  @doc "Replaces the fresh-session system instruction without changing other inputs."
  @spec put_system_prompt(t(), String.t()) :: t()
  def put_system_prompt(%__MODULE__{operation: :create} = input, system_prompt)
      when is_binary(system_prompt) do
    %{input | system_prompt: system_prompt}
  end
end
