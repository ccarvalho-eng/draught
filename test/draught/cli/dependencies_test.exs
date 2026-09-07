defmodule Draught.CLI.DependenciesTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Dependencies
  alias Draught.Validation.Error

  test "builds the local production boundaries by default" do
    assert {:ok, %Dependencies{} = dependencies} = Dependencies.new()
    assert {Draught.CLI.System.Local, nil} = dependencies.system
    assert dependencies.discovery_http == Draught.Provider.Ollama.Discovery.HTTP.Req
  end

  test "rejects incomplete system and discovery boundaries" do
    assert {:error, %Error{}} = Dependencies.new(system: {String, nil})
    assert {:error, %Error{}} = Dependencies.new(discovery_http: String)
  end
end
