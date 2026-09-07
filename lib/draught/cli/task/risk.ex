defmodule Draught.CLI.Task.Risk do
  @moduledoc false

  alias Draught.CLI.Task.Approval.Fixed
  alias Draught.Tool.Approval.Policy.Default
  alias Draught.Tool.Risk
  alias Draught.Validation.Error

  @type mode :: :deny | :ask | :allow
  @type resolution :: {[Risk.t()], Draught.Tool.Approval.policy()}

  @doc "Maps a CLI risk mode to admitted risk classes and an approval policy."
  @spec resolve(term()) :: {:ok, resolution()} | {:error, Error.t()}
  def resolve(:deny) do
    {:ok, {[:read], {Default, nil}}}
  end

  def resolve(:ask) do
    {:ok, {Risk.classes(), {Default, nil}}}
  end

  def resolve(:allow) do
    {:ok, {Risk.classes(), {Fixed, :allow}}}
  end

  def resolve(_mode) do
    Error.single([:risk], :invalid_value, "must be deny, ask, or allow")
  end
end
