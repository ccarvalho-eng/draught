defmodule Draught.Validation.Error do
  @moduledoc """
  Contains one or more safe, deterministic construction violations.

  Validation errors describe expected malformed input and deliberately avoid
  retaining rejected values.
  """

  alias Draught.Validation.Violation

  @enforce_keys [:violations]
  defstruct [:violations]

  @type t :: %__MODULE__{violations: nonempty_list(Violation.t())}
  @type result(value) :: {:ok, value} | {:error, t()}

  @doc "Builds an error from a non-empty collection of violations."
  @spec new(nonempty_list(Violation.t())) :: t()
  def new([%Violation{} | _rest] = violations) do
    %__MODULE__{violations: Enum.sort_by(violations, &sort_key/1)}
  end

  @doc "Returns an error tuple containing one safe violation."
  @spec single([Violation.path_segment()], Violation.code(), String.t()) :: {:error, t()}
  def single(path, code, message) do
    violation = Violation.new(path, code, message)
    {:error, new([violation])}
  end

  defp sort_key(%Violation{path: path, code: code}) do
    {Enum.map(path, &inspect/1), code}
  end
end
