defmodule Draught.CLI.Session.Catalog.Name do
  @moduledoc """
  Validates bounded human-readable session names independently of storage identifiers.

  Names may contain Unicode and spaces but not surrounding whitespace, control
  characters, terminal escapes, or more than 128 bytes.
  """

  alias Draught.CLI.UI.SafeLine
  alias Draught.Validation.Error

  @maximum_bytes 128
  @control ~r/[[:cntrl:]]/u

  @doc "Validates one display name without converting user input to atoms."
  @spec validate(term()) :: Error.result(String.t())
  def validate(value) when is_binary(value) do
    with true <- String.valid?(value),
         true <- byte_size(value) > 0,
         true <- byte_size(value) <= @maximum_bytes,
         true <- String.trim(value) == value,
         false <- Regex.match?(@control, value),
         ^value <- String.normalize(value, :nfc),
         ^value <- SafeLine.text(value, @maximum_bytes) do
      {:ok, value}
    else
      _result -> invalid()
    end
  end

  def validate(_value) do
    invalid()
  end

  defp invalid do
    Error.single(
      [:session_name],
      :invalid_value,
      "must be a trimmed printable name of at most 128 bytes"
    )
  end
end
