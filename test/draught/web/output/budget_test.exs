defmodule Draught.Web.Output.BudgetTest do
  use ExUnit.Case, async: true

  alias Draught.Web.Output.Budget

  test "matches Jason's encoded size for escaped and multibyte strings" do
    value = %{
      "content" => "quote: \" slash: \\ newline:\n nul:\0 unicode: łódź",
      "items" => ["one", "two"]
    }

    encoded_bytes =
      value
      |> Jason.encode!()
      |> byte_size()

    assert :ok = Budget.validate(value, encoded_bytes)
    assert {:error, :too_large} = Budget.validate(value, encoded_bytes - 1)
  end
end
