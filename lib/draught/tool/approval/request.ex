defmodule Draught.Tool.Approval.Request do
  @moduledoc """
  Bounded metadata presented when a tool needs an approval decision.

  Summaries exclude raw arguments. An optional display-only preview carries
  escaped operation details and must be treated as sensitive content, not logs.
  """

  alias Draught.Tool.Approval.Preview
  alias Draught.Tool.Name
  alias Draught.Tool.Risk
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @maximum_call_id_bytes 128
  @maximum_target_bytes 512
  @maximum_summary_bytes 1_024
  @control_bytes ~r/[\x00-\x1F\x7F]/
  @unicode_display_controls ~r/[\x{0080}-\x{009F}\x{061C}\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/u

  @enforce_keys [:call_id, :tool, :target, :arguments_summary, :risk]
  defstruct [:call_id, :tool, :target, :arguments_summary, :risk, :preview]

  @type preview :: Preview.t() | nil
  @type t :: %__MODULE__{
          call_id: String.t(),
          tool: String.t(),
          target: String.t(),
          arguments_summary: String.t(),
          risk: Risk.t(),
          preview: preview()
        }

  @doc "Builds an approval request from pre-sanitized bounded metadata."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes) do
    with {:ok, normalized} <-
           Attributes.normalize(
             attributes,
             [:call_id, :tool, :target, :arguments_summary, :risk, :preview]
           ),
         {:ok, request} <- build(normalized),
         {:ok, preview} <- preview(normalized) do
      {:ok, %{request | preview: preview}}
    end
  end

  defp preview(attributes) do
    attributes
    |> Map.get(:preview)
    |> Preview.validate()
  end

  defp build(normalized) do
    with {:ok, call_id} <- bounded_string(normalized, :call_id, @maximum_call_id_bytes),
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
         :ok <- validate_size(value, key, maximum),
         :ok <- validate_display_characters(value, key) do
      {:ok, value}
    end
  end

  defp validate_size(value, _key, maximum) when byte_size(value) <= maximum do
    :ok
  end

  defp validate_size(_value, key, _maximum) do
    Error.single([key], :too_large, "exceeds the maximum byte size")
  end

  defp validate_display_characters(value, key) do
    safe? =
      String.valid?(value) and
        not Regex.match?(@control_bytes, value) and
        not Regex.match?(@unicode_display_controls, value)

    validate_display_result(safe?, key)
  end

  defp validate_display_result(true, _key) do
    :ok
  end

  defp validate_display_result(false, key) do
    Error.single([key], :invalid_value, "must not contain control characters")
  end

  defp risk(attributes) do
    with {:ok, risk} <- Attributes.fetch_required(attributes, :risk) do
      Risk.validate(risk)
    end
  end
end
