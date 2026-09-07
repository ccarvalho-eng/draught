defmodule Draught.Telemetry.Outcome do
  @moduledoc """
  Projects operation results into the telemetry outcome allowlist.

  Known validation and normalized failures retain only their error category;
  unexpected result shapes are classified as protocol errors.
  """

  alias Draught.Error.Normalized
  alias Draught.Tool.Result
  alias Draught.Validation.Error

  @type metadata :: %{
          required(:error_kind) => Normalized.kind() | :validation | nil,
          required(:outcome) => :error | :ok
        }

  @doc "Projects a canonical operation result into allowlisted metadata."
  @spec result(term()) :: metadata()
  def result({:ok, %Result{status: :error, error: %Normalized{kind: kind}}}) do
    %{error_kind: kind, outcome: :error}
  end

  def result({:ok, %Result{status: :success}}) do
    %{error_kind: nil, outcome: :ok}
  end

  def result({:ok, _value}) do
    %{error_kind: nil, outcome: :ok}
  end

  def result({:error, %Normalized{kind: kind}}) do
    %{error_kind: kind, outcome: :error}
  end

  def result({:error, %Error{}}) do
    %{error_kind: :validation, outcome: :error}
  end

  def result(_result) do
    %{error_kind: :protocol, outcome: :error}
  end
end
