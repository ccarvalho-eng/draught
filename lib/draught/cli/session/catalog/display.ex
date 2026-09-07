defmodule Draught.CLI.Session.Catalog.Display do
  @moduledoc """
  Validates bounded single-line values before catalog rendering.

  Persisted provider bindings are untrusted input. Display values must already
  be normalized and unchanged by the CLI sanitizer so catalog rows cannot be
  split, reordered, or made visually ambiguous.
  """

  alias Draught.CLI.UI.SafeLine

  @maximum_bytes 512

  @doc "Accepts one normalized display value that needs no sanitization."
  @spec validate(term()) :: {:ok, String.t()} | {:error, :unsafe}
  def validate(value) when is_binary(value) do
    with true <- byte_size(value) > 0,
         true <- byte_size(value) <= @maximum_bytes,
         true <- String.valid?(value),
         ^value <- String.normalize(value, :nfc),
         ^value <- SafeLine.text(value, @maximum_bytes) do
      {:ok, value}
    else
      _result -> {:error, :unsafe}
    end
  end

  def validate(_value) do
    {:error, :unsafe}
  end
end
