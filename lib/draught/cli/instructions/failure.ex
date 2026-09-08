defmodule Draught.CLI.Instructions.Failure do
  @moduledoc """
  Constructs bounded failures for AGENTS.md loading and validation.
  """

  alias Draught.Error.Normalized

  @doc "Builds the failure returned when combined guidance exceeds its byte limit."
  @spec too_large() :: Normalized.t()
  def too_large do
    error(
      "agents_instructions_too_large",
      "AGENTS.md instructions exceed the 32 KiB limit"
    )
  end

  @doc "Builds the failure returned for invalid guidance text."
  @spec invalid() :: Normalized.t()
  def invalid do
    error(
      "invalid_agents_instructions",
      "AGENTS.md instructions must be valid UTF-8 text without null bytes"
    )
  end

  @doc "Builds the failure returned for a non-regular guidance source."
  @spec unsafe() :: Normalized.t()
  def unsafe do
    error(
      "unsafe_agents_instructions",
      "AGENTS.md instructions must be stored in a regular file"
    )
  end

  @doc "Builds the failure returned when guidance cannot be read."
  @spec unavailable() :: Normalized.t()
  def unavailable do
    error(
      "agents_instructions_unavailable",
      "AGENTS.md instructions could not be read"
    )
  end

  defp error(code, message) do
    {:ok, error} =
      Normalized.new(
        :configuration,
        code,
        message,
        retryable: false
      )

    error
  end
end
