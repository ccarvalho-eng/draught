defmodule Draught.Provider.Ollama.Discovery.Model.Name do
  @moduledoc """
  Validates Ollama model identifiers used in requests and diagnostic output.

  Accepted identifiers are bounded ASCII strings using Ollama's name and tag
  separators.
  """

  @pattern ~r/\A[A-Za-z0-9][A-Za-z0-9._:\/-]{0,255}\z/

  @doc "Returns whether a model identifier is bounded and safe for requests and display."
  @spec valid?(term()) :: boolean()
  def valid?(value) when is_binary(value) do
    String.valid?(value) and Regex.match?(@pattern, value)
  end

  def valid?(_value) do
    false
  end
end
