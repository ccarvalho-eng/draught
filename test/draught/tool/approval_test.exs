defmodule Draught.Tool.ApprovalTest do
  use ExUnit.Case, async: true

  alias Draught.Error.Normalized
  alias Draught.Tool.Approval
  alias Draught.Tool.Approval.Decision
  alias Draught.Tool.Approval.Policy.Default
  alias Draught.Tool.Approval.Request
  alias Draught.Validation.Error

  defmodule Policy do
    @behaviour Draught.Tool.Approval.Policy

    @impl Draught.Tool.Approval.Policy
    def decide(request, owner) do
      send(owner, {:approval_requested, request})
      Decision.new(outcome: :deny, reason: "operator denied")
    end
  end

  test "constructs a bounded request without retaining raw arguments" do
    oversized_id = String.duplicate("a", 129)
    oversized_summary = String.duplicate("a", 1_025)

    assert {:ok, request} = request(:write)
    assert request.call_id == "call-1"
    assert request.tool == "write_file"
    assert request.target == "lib/example.ex"
    assert request.arguments_summary == "path; content: 120 bytes"
    assert request.risk == :write

    request_fields = Map.from_struct(request)
    refute Map.has_key?(request_fields, :arguments)

    assert {:error, %Error{}} =
             Request.new(
               call_id: "call-1",
               tool: "write_file",
               target: "lib/example.ex",
               arguments_summary: oversized_summary,
               risk: :write
             )

    assert {:error, %Error{}} =
             Request.new(
               call_id: oversized_id,
               tool: "write_file",
               target: "lib/example.ex",
               arguments_summary: "path",
               risk: :write
             )

    assert {:error, %Error{}} =
             Request.new(
               call_id: "call-1",
               tool: "write_file",
               target: "lib/example.ex\nconfirm",
               arguments_summary: "path",
               risk: :write
             )
  end

  test "allows reads and asks for effectful risks by default" do
    for risk <- [:read, :write, :execute, :network] do
      {:ok, request} = request(risk)
      assert {:ok, decision} = Approval.decide({Default, nil}, request)

      assert decision.outcome == expected_outcome(risk)
    end
  end

  test "invokes an injected policy with a reconstructed request" do
    {:ok, request} = request(:write)

    assert {:ok, %Decision{outcome: :deny, reason: "operator denied"}} =
             Approval.decide({Policy, self()}, request)

    assert_received {:approval_requested, ^request}
  end

  test "normalizes invalid adapters and policy results" do
    {:ok, request} = request(:read)

    assert {:error, %Normalized{kind: :configuration, code: "invalid_approval_policy"}} =
             Approval.decide({String, nil}, request)

    assert {:error, %Normalized{kind: :configuration, code: "invalid_approval_request"}} =
             Approval.decide({Default, nil}, %{tool: "missing identity"})

    assert {:error, %Error{}} = Decision.new(outcome: :deny, reason: "unsafe\nreason")
  end

  defp request(risk) do
    Request.new(
      call_id: "call-1",
      tool: "write_file",
      target: "lib/example.ex",
      arguments_summary: "path; content: 120 bytes",
      risk: risk
    )
  end

  defp expected_outcome(:read) do
    :allow
  end

  defp expected_outcome(_risk) do
    :ask
  end
end
