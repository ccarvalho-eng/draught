defmodule Draught.CLI.EntryPoint.GuardTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.EntryPoint.Guard

  test "returns successful boundary results unchanged" do
    assert Guard.run("value", fn value -> String.upcase(value) end) == {:ok, "VALUE"}
  end

  test "normalizes expected runtime exception classes" do
    assert Guard.run(nil, fn _input -> raise "failure" end) == :error
    assert Guard.run(nil, fn _input -> raise ArgumentError, "failure" end) == :error
  end
end
