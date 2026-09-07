defmodule Draught.CLI.Interactive.Session.Reference do
  @moduledoc """
  Validates session command references and creates fresh immutable identifiers.

  Display names, generated identifiers, and catalog uniqueness remain separate
  so command orchestration can operate only on validated values.
  """

  alias Draught.CLI.Dependencies
  alias Draught.CLI.Interactive.State
  alias Draught.CLI.Session.Catalog.Name
  alias Draught.Session.Identifier

  @doc "Returns a generated identifier or validates an explicit fresh-session identifier."
  @spec fresh(String.t() | nil, Dependencies.t()) ::
          {:ok, String.t()} | {:error, :identifier_unavailable}
  def fresh(nil, %Dependencies{task: task_dependencies}) do
    case task_dependencies.identifier.() do
      {:ok, value} -> identifier_result(Identifier.new(value))
      _result -> {:error, :identifier_unavailable}
    end
  end

  def fresh(value, %Dependencies{}) do
    identifier_result(Identifier.new(value))
  end

  @doc "Validates a human-readable session display name."
  @spec name(String.t() | nil) :: {:ok, String.t()} | {:error, term()}
  def name(value) do
    Name.validate(value)
  end

  @doc "Resolves the archive target, defaulting to the persisted current session."
  @spec archive(String.t() | nil, State.t()) ::
          {:ok, String.t()} | {:error, :session_not_persisted}
  def archive(nil, %State{persisted?: true, session_id: identifier}) do
    {:ok, identifier}
  end

  def archive(nil, %State{persisted?: false}) do
    {:error, :session_not_persisted}
  end

  def archive(reference, %State{}) do
    {:ok, reference}
  end

  defp identifier_result({:ok, identifier}) do
    {:ok, identifier}
  end

  defp identifier_result({:error, _error}) do
    {:error, :identifier_unavailable}
  end
end
