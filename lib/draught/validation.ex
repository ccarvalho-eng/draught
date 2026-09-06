defmodule Draught.Validation do
  @moduledoc """
  Small facade for constructing namespaced validation failures.
  """

  alias Draught.Validation.Error
  alias Draught.Validation.Violation

  @type result(value) :: Error.result(value)

  @doc "Builds an error from a non-empty list of violations."
  @spec new_error(nonempty_list(Violation.t())) :: Error.t()
  def new_error(violations) do
    Error.new(violations)
  end

  @doc "Returns an error tuple containing one safe violation."
  @spec error([Violation.path_segment()], Violation.code(), String.t()) :: {:error, Error.t()}
  def error(path, code, message) do
    Error.single(path, code, message)
  end
end
