defmodule Draught.Tool.Approval.Request do
  @moduledoc """
  Sanitized metadata presented when a tool needs an approval decision.

  Raw tool arguments are deliberately excluded from this value.
  """

  alias Draught.Tool.Name
  alias Draught.Tool.Risk
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @maximum_call_id_bytes 128
  @maximum_target_bytes 512
  @maximum_summary_bytes 1_024
  @control_bytes ~r/[\x00-\x1F\x7F]/

  @enforce_keys [:call_id, :tool, :target, :arguments_summary, :risk]
  defstruct [:call_id, :tool, :target, :arguments_summary, :risk]

  @type t :: %__MODULE__{
          call_id: String.t(),
          tool: String.t(),
          target: String.t(),
          arguments_summary: String.t(),
          risk: Risk.t()
        }

  @doc "Builds an approval request from pre-sanitized bounded metadata."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes) do
    with {:ok, normalized} <-
           Attributes.normalize(
             attributes,
             [:call_id, :tool, :target, :arguments_summary, :risk]
           ),
         {:ok, call_id} <- bounded_string(normalized, :call_id, @maximum_call_id_bytes),
         {:ok, tool} <- tool(normalized),
         {:ok, target} <- bounded_string(normalized, :target, @maximum_target_bytes),
         {:ok, summary} <-
           bounded_string(normalized, :arguments_summary, @maximum_summary_bytes),
         {:ok, risk} <- risk(normalized) do
      {:ok,
       %__MODULE__{
         call_id: call_id,
         tool: tool,
         target: target,
         arguments_summary: summary,
         risk: risk
       }}
    end
  end

  defp tool(attributes) do
    with {:ok, tool} <- Attributes.fetch_required(attributes, :tool) do
      Name.validate(tool, [:tool])
    end
  end

  defp bounded_string(attributes, key, maximum) do
    with {:ok, value} <- Value.required_string(attributes, key),
         true <- byte_size(value) <= maximum,
         false <- Regex.match?(@control_bytes, value) do
      {:ok, value}
    else
      true -> Error.single([key], :invalid_value, "must not contain control characters")
      false -> Error.single([key], :too_large, "exceeds the maximum byte size")
      {:error, %Error{}} = result -> result
    end
  end

  defp risk(attributes) do
    with {:ok, risk} <- Attributes.fetch_required(attributes, :risk) do
      Risk.validate(risk)
    end
  end
end
