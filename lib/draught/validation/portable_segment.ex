defmodule Draught.Validation.PortableSegment do
  @moduledoc """
  Validates one bounded path segment used in generated local names.
  """

  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @format ~r/\A[A-Za-z0-9][A-Za-z0-9._-]{0,127}\z/

  @doc "Validates one segment without separators or traversal names."
  @spec validate(term(), [term()]) :: Error.result(String.t())
  def validate(value, path) do
    with {:ok, segment} <- Value.string(value, path),
         true <- Regex.match?(@format, segment),
         false <- segment in [".", ".."] do
      {:ok, segment}
    else
      _invalid ->
        Error.single(
          path,
          :invalid_value,
          "must be a portable path segment of at most 128 bytes"
        )
    end
  end
end
