defmodule Draught.Tool.Executor.Dispatch do
  @moduledoc false

  alias Draught.Error.Normalized
  alias Draught.Tool.Execution.Context
  alias Draught.Tool.Execution.Failure

  @result_error_kinds [:cancellation, :policy, :timeout, :tool]

  @doc "Invokes an executor and validates its bounded canonical result."
  @spec execute({module(), term()}, Draught.Tool.Call.t(), Context.t()) ::
          {:ok, String.t()} | {:error, Normalized.t()}
  def execute({module, configuration}, call, %Context{} = context) do
    module
    |> then(& &1.execute(call, context, configuration))
    |> normalize(context.policy.max_output_bytes)
  end

  defp normalize({:ok, content}, maximum_bytes)
       when is_binary(content) and byte_size(content) <= maximum_bytes do
    valid_content(content)
  end

  defp normalize({:ok, content}, _maximum_bytes) when is_binary(content) do
    {:error, Failure.tool_output_too_large()}
  end

  defp normalize({:error, %Normalized{} = error}, _maximum_bytes) do
    normalize_error(error)
  end

  defp normalize(_result, _maximum_bytes) do
    {:error, Failure.invalid_tool_result()}
  end

  defp valid_content(content) do
    content
    |> String.valid?()
    |> valid_content_result(content)
  end

  defp valid_content_result(true, content) do
    {:ok, content}
  end

  defp valid_content_result(false, _content) do
    {:error, Failure.invalid_tool_result()}
  end

  defp normalize_error(error) do
    result =
      error
      |> Map.from_struct()
      |> Normalized.new()

    case result do
      {:ok, %Normalized{kind: kind} = canonical} when kind in @result_error_kinds ->
        {:error, canonical}

      _result ->
        {:error, Failure.invalid_tool_result()}
    end
  end
end
