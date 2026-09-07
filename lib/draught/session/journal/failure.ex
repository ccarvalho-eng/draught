defmodule Draught.Session.Journal.Failure do
  @moduledoc false

  alias Draught.Error.Normalized

  @doc "Builds a journal I/O failure without exposing filesystem details."
  @spec io() :: Normalized.t()
  def io do
    error("journal_io_error", "Session journal storage is unavailable")
  end

  @doc "Builds a corrupt-journal failure."
  @spec corrupt() :: Normalized.t()
  def corrupt do
    error("journal_corrupt", "Session journal data is invalid or incomplete")
  end

  @doc "Builds an unsupported-schema failure."
  @spec unsupported_version() :: Normalized.t()
  def unsupported_version do
    error("journal_version_unsupported", "Session journal schema is newer than supported")
  end

  defp error(code, message) do
    {:ok, error} = Normalized.new(:protocol, code, message, retryable: false)
    error
  end
end
