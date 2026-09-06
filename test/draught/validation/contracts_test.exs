defmodule Draught.Validation.ContractsTest do
  use ExUnit.Case, async: true

  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.JSON
  alias Draught.Validation.Value
  alias Draught.Validation.Violation

  describe "attribute normalization" do
    test "accepts whitelisted atom and string keys" do
      assert {:ok, %{name: "draught"}} = Attributes.normalize(%{"name" => "draught"}, [:name])
      assert {:ok, %{name: "draught"}} = Attributes.normalize([name: "draught"], [:name])
    end

    test "rejects unknown, duplicate, and malformed attributes" do
      assert {:error, %Error{violations: [%{code: :unknown_key}]}} =
               Attributes.normalize(%{"other" => true}, [:name])

      assert {:error, %Error{violations: [%{code: :duplicate_key, path: [:name]}]}} =
               Attributes.normalize(%{:name => "one", "name" => "two"}, [:name])

      assert {:error, %Error{violations: [%{code: :invalid_type}]}} =
               Attributes.normalize(["not a keyword"], [:name])
    end

    test "reports a missing required attribute without retaining input" do
      assert {:error, %Error{violations: [violation]}} = Attributes.fetch_required(%{}, :token)
      assert violation == Violation.new([:token], :required, "is required")
    end
  end

  describe "JSON validation" do
    test "accepts nested JSON-compatible values" do
      assert :ok = JSON.validate(%{"items" => [nil, true, 1, 1.5, "text", %{"ok" => false}]})
      assert :ok = JSON.validate_object(%{})
    end

    test "rejects non-object roots, atom keys, unsupported values, and excessive depth" do
      assert {:error, %Error{violations: [%{code: :invalid_type}]}} =
               JSON.validate_object([])

      assert {:error, %Error{violations: [%{path: [:unknown]}]}} =
               JSON.validate(%{unsafe: true})

      secret_key = {:token, "do-not-retain"}
      assert {:error, error} = JSON.validate(%{secret_key => true})
      refute inspect(error) =~ "do-not-retain"

      assert {:error, %Error{violations: [%{code: :invalid_type}]}} =
               JSON.validate({:tuple, true})

      assert {:error, %Error{violations: [%{code: :invalid_value}]}} =
               JSON.validate(<<255>>)

      assert {:error, %Error{violations: [%{code: :invalid_value}]}} =
               JSON.validate(%{<<255>> => "value"})

      assert {:error, %Error{violations: [%{code: :too_large}]}} =
               "a"
               |> String.duplicate(1_048_577)
               |> JSON.validate()

      wide_list = List.duplicate(nil, 1_001)
      assert {:error, %Error{violations: [%{code: :too_large}]}} = JSON.validate(wide_list)

      long_key = String.duplicate("k", 257)

      assert {:error, %Error{violations: [%{code: :too_large}]}} =
               JSON.validate(%{long_key => nil})

      too_deep = Enum.reduce(1..17, "value", fn _index, nested -> [nested] end)

      assert {:error, %Error{violations: [%{code: :too_deep}]}} = JSON.validate(too_deep)
    end
  end

  describe "scalar validation" do
    test "validates strings, booleans, integers, ranges, and enums" do
      assert {:ok, "value"} = Value.required_string(%{key: "value"}, :key)
      assert {:ok, ""} = Value.string("", [:key], allow_empty: true)
      assert {:ok, true} = Value.boolean(true, [:key])
      assert {:ok, 0} = Value.non_negative_integer(0, [:key])
      assert {:ok, 1} = Value.positive_integer(1, [:key])
      assert {:ok, 0.5} = Value.number_in_range(0.5, 0, 1, [:key])
      assert {:ok, :text} = Value.enum("text", [:text], [:key])
    end

    test "returns structured failures for invalid scalar values" do
      assertions = [
        Value.string("", [:string]),
        Value.boolean(:yes, [:boolean]),
        Value.non_negative_integer(-1, [:count]),
        Value.positive_integer(0, [:count]),
        Value.number_in_range(3, 0, 2, [:temperature]),
        Value.enum("unknown", [:known], [:kind])
      ]

      assert Enum.all?(assertions, &match?({:error, %Error{}}, &1))
    end
  end

  test "validation errors sort violations deterministically" do
    error =
      Error.new([
        Violation.new([:z], :required, "is required"),
        Violation.new([:a], :invalid_type, "is invalid")
      ])

    assert Enum.map(error.violations, & &1.path) == [[:a], [:z]]
  end
end
