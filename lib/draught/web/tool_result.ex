defmodule Draught.Web.ToolResult do
  @moduledoc """
  Converts validated web content into canonical tool results.

  Successful output is marked with untrusted web provenance. Adapter failures are
  reduced to the error kinds accepted by the tool boundary.
  """

  alias Draught.Error.Normalized
  alias Draught.Tool.Output
  alias Draught.Tool.Result.Provenance
  alias Draught.Validation.Error
  alias Draught.Web.Failure

  @accepted_error_kinds [:cancellation, :policy, :timeout, :tool]

  @doc "Builds a provenance-bearing tool output from validated web content."
  @spec output(String.t(), [String.t()], pos_integer()) ::
          {:ok, Output.t()} | {:error, Normalized.t()}
  def output(content, sources, maximum_bytes) do
    with true <- byte_size(content) <= maximum_bytes,
         {:ok, provenance} <-
           Provenance.new(origin: :web, trust: :untrusted, sources: sources),
         {:ok, output} <- Output.new(content: content, provenance: provenance) do
      {:ok, output}
    else
      false -> {:error, Failure.response_too_large()}
      {:error, %Error{}} -> {:error, Failure.invalid_result()}
    end
  end

  @doc "Normalizes adapter errors to the closed tool-result error set."
  @spec error(term()) :: {:error, Normalized.t()}
  def error(%Normalized{kind: kind} = error) when kind in @accepted_error_kinds do
    error
    |> Map.from_struct()
    |> Normalized.new()
    |> normalized_error()
  end

  def error(_error) do
    {:error, Failure.request_failed()}
  end

  defp normalized_error({:ok, canonical}) do
    {:error, canonical}
  end

  defp normalized_error({:error, _error}) do
    {:error, Failure.request_failed()}
  end
end
