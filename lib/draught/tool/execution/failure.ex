defmodule Draught.Tool.Execution.Failure do
  @moduledoc """
  Constructs normalized tool execution and approval failures.

  Validation details are reduced to bounded hints, and every returned failure
  is non-retryable with a stable category and code.
  """

  alias Draught.Error.Normalized
  alias Draught.Validation.Error
  alias Draught.Validation.Violation

  @doc "Builds a normalized failure from a safe argument-validation error."
  @spec invalid_arguments(Error.t()) :: Normalized.t()
  def invalid_arguments(%Error{violations: [violation | _rest]}) do
    normalized(
      :tool,
      "invalid_arguments",
      "Tool arguments do not match the registered schema",
      hint: violation_hint(violation)
    )
  end

  @doc "Builds the failure returned when policy excludes a tool risk."
  @spec tool_risk_denied() :: Normalized.t()
  def tool_risk_denied do
    normalized(
      :policy,
      "tool_risk_denied",
      "Tool risk is not allowed by the execution policy"
    )
  end

  @doc "Builds the failure returned for a malformed executor result."
  @spec invalid_tool_result() :: Normalized.t()
  def invalid_tool_result do
    normalized(:tool, "invalid_tool_result", "Tool executor returned an invalid result")
  end

  @doc "Builds the failure returned when executor output exceeds policy."
  @spec tool_output_too_large() :: Normalized.t()
  def tool_output_too_large do
    normalized(:tool, "tool_output_too_large", "Tool output exceeds the configured byte limit")
  end

  @doc "Builds the policy failure returned when confirmation is required."
  @spec approval_required() :: Normalized.t()
  def approval_required do
    normalized(:policy, "approval_required", "Tool execution requires approval")
  end

  @doc "Builds the policy failure returned when approval is denied."
  @spec approval_denied(String.t() | nil) :: Normalized.t()
  def approval_denied(reason) do
    normalized(:policy, "approval_denied", "Tool execution was denied", hint: reason)
  end

  @doc "Builds the policy failure returned when a repeated call is skipped."
  @spec duplicate_tool_call() :: Normalized.t()
  def duplicate_tool_call do
    normalized(:policy, "duplicate_tool_call", "Repeated tool call was not executed")
  end

  defp normalized(kind, code, message, options \\ []) do
    {:ok, error} = Normalized.new(kind, code, message, Keyword.put(options, :retryable, false))
    error
  end

  defp violation_hint(%Violation{path: path, message: message}) do
    location = Enum.map_join(path, ".", &to_string/1)
    "#{location} #{message}"
  end
end
