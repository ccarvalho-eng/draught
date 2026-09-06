defmodule Draught.Error.NormalizedTest do
  use ExUnit.Case, async: true

  alias Draught.Error.Normalized
  alias Draught.Validation

  test "constructs every closed runtime error kind" do
    assert Normalized.kinds() == [
             :cancellation,
             :capability,
             :configuration,
             :policy,
             :protocol,
             :timeout,
             :tool,
             :transport
           ]

    Enum.each(Normalized.kinds(), fn kind ->
      assert {:ok, %Normalized{kind: ^kind, retryable: false}} =
               Normalized.new(kind, :failure, "safe failure")
    end)
  end

  test "normalizes string kinds and optional safe fields" do
    assert {:ok, error} =
             Normalized.new(%{
               "kind" => "transport",
               "code" => "connection_failed",
               "message" => "connection failed",
               "hint" => "retry later",
               "retryable" => true
             })

    assert error == %Normalized{
             kind: :transport,
             code: "connection_failed",
             message: "connection failed",
             hint: "retry later",
             retryable: true
           }
  end

  test "rejects unsupported kinds and malformed safe fields" do
    invalid_values = [
      %{kind: :unknown, code: :failure, message: "failure"},
      %{kind: :tool, code: "", message: "failure"},
      %{kind: :tool, code: :failure, message: ""},
      %{kind: :tool, code: :failure, message: "failure", hint: ""},
      %{kind: :tool, code: :failure, message: "failure", retryable: :yes},
      %{kind: :tool, code: :failure, message: "failure", raw_cause: "secret"}
    ]

    Enum.each(invalid_values, fn value ->
      assert {:error, %Validation.Error{}} = Normalized.new(value)
    end)
  end

  test "normalizes atom codes and rejects invalid UTF-8 strings" do
    assert {:ok, %Normalized{code: "failure"}} =
             Normalized.new(:tool, :failure, "failure")

    invalid_values = [
      %{kind: :tool, code: <<255>>, message: "failure"},
      %{kind: :tool, code: "failure", message: <<255>>},
      %{kind: :tool, code: "failure", message: "failure", hint: <<255>>}
    ]

    Enum.each(invalid_values, fn value ->
      assert {:error, %Validation.Error{}} = Normalized.new(value)
    end)
  end
end
