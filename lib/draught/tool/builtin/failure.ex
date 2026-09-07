defmodule Draught.Tool.Builtin.Failure do
  @moduledoc false

  alias Draught.Error.Normalized

  @doc "Builds a safe failure for a rejected workspace path."
  @spec invalid_path() :: {:error, Normalized.t()}
  def invalid_path do
    error("invalid_path", "Path is not available inside the workspace")
  end

  @doc "Builds a safe failure for an oversized file."
  @spec file_too_large() :: {:error, Normalized.t()}
  def file_too_large do
    error("file_too_large", "File exceeds the configured output limit")
  end

  @doc "Builds a safe failure for an unreadable file."
  @spec read_failed() :: {:error, Normalized.t()}
  def read_failed do
    error("read_failed", "File could not be read")
  end

  @doc "Builds a safe failure for a directory listing error."
  @spec list_failed() :: {:error, Normalized.t()}
  def list_failed do
    error("list_failed", "Directory could not be listed")
  end

  @doc "Builds a safe failure for an invalid search query."
  @spec invalid_query() :: {:error, Normalized.t()}
  def invalid_query do
    error("invalid_query", "Search query must be a non-empty string of at most 256 bytes")
  end

  @doc "Builds a safe failure for a workspace search error."
  @spec search_failed() :: {:error, Normalized.t()}
  def search_failed do
    error("search_failed", "Workspace could not be searched")
  end

  @doc "Builds a safe failure for a search scan limit."
  @spec search_limit_exceeded() :: {:error, Normalized.t()}
  def search_limit_exceeded do
    error("search_limit_exceeded", "Workspace search exceeded a scan limit")
  end

  defp error(code, message) do
    {:ok, error} = Normalized.new(:tool, code, message, retryable: false)
    {:error, error}
  end
end
