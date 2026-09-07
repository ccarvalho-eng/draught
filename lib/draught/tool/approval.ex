defmodule Draught.Tool.Approval do
  @moduledoc """
  Validates and invokes an explicitly injected approval policy.
  """

  alias Draught.Error.Normalized
  alias Draught.Tool.Approval.Decision
  alias Draught.Tool.Approval.Policy.Adapter
  alias Draught.Tool.Approval.Request

  @type policy :: {module(), term()}
  @type result :: {:ok, Decision.t()} | {:error, Normalized.t()}

  @doc "Requests a decision from a policy using a reconstructed request."
  @spec decide(policy(), Request.t() | map() | keyword()) :: result()
  def decide(policy, request) do
    with {:ok, module, configuration} <- Adapter.validate(policy),
         {:ok, canonical_request} <- normalize_request(request),
         result <- module.decide(canonical_request, configuration) do
      normalize_decision(result)
    end
  end

  defp normalize_request(%Request{} = request) do
    request
    |> Map.from_struct()
    |> normalize_request()
  end

  defp normalize_request(request) do
    case Request.new(request) do
      {:ok, canonical} -> {:ok, canonical}
      {:error, _error} -> configuration_error("invalid_approval_request")
    end
  end

  defp normalize_decision({:ok, %Decision{} = decision}) do
    decision
    |> Map.from_struct()
    |> Decision.new()
    |> normalize_decision_value()
  end

  defp normalize_decision({:error, %Normalized{kind: :policy} = error}) do
    error
    |> Map.from_struct()
    |> Normalized.new()
    |> normalize_policy_error()
  end

  defp normalize_decision(_result) do
    configuration_error("invalid_approval_result")
  end

  defp normalize_decision_value({:ok, decision}) do
    {:ok, decision}
  end

  defp normalize_decision_value({:error, _error}) do
    configuration_error("invalid_approval_result")
  end

  defp normalize_policy_error({:ok, error}) do
    {:error, error}
  end

  defp normalize_policy_error({:error, _error}) do
    configuration_error("invalid_approval_result")
  end

  defp configuration_error(code) do
    message = configuration_message(code)
    {:ok, error} = Normalized.new(:configuration, code, message, retryable: false)
    {:error, error}
  end

  defp configuration_message("invalid_approval_policy") do
    "approval policy is invalid"
  end

  defp configuration_message("invalid_approval_request") do
    "approval request is invalid"
  end

  defp configuration_message("invalid_approval_result") do
    "approval policy returned an invalid result"
  end
end
