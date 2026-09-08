defmodule Draught.CLI.Interactive.Model.ReferenceTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Interactive.Model.Reference

  test "resolves exact names before one-based positions" do
    models = ["2", "deepseek-r1", "qwen3"]

    assert Reference.resolve("2", models) == {:ok, "2"}
    assert Reference.resolve("3", models) == {:ok, "qwen3"}
    assert Reference.exact("2", models) == {:ok, "2"}
  end

  test "rejects missing and out-of-range references" do
    models = ["deepseek-r1", "qwen3"]

    assert Reference.resolve("missing", models) == {:error, :not_found}
    assert Reference.resolve("0", models) == {:error, :not_found}
    assert Reference.resolve("3", models) == {:error, :not_found}
    assert Reference.exact("1", models) == {:error, :not_found}
  end
end
