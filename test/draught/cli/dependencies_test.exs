defmodule Draught.CLI.DependenciesTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Dependencies
  alias Draught.Validation.Error

  test "builds the local production boundaries by default" do
    assert {:ok, %Dependencies{} = dependencies} = Dependencies.new()
    assert {Draught.CLI.System.Local, nil} = dependencies.system

    assert {Draught.Skill.Repository.Local,
            %{builtin_repository: {Draught.Skill.Repository.Builtin, nil}}} =
             dependencies.skill_repository

    assert dependencies.discovery_http == Draught.Provider.Ollama.Discovery.HTTP.Req
  end

  test "rejects incomplete system and discovery boundaries" do
    assert {:error, %Error{}} = Dependencies.new(system: {String, nil})
    assert {:error, %Error{}} = Dependencies.new(discovery_http: String)
    assert {:error, %Error{}} = Dependencies.new(catalog: {String, nil})
    assert {:error, %Error{}} = Dependencies.new(terminal: {String, nil})
    assert {:error, %Error{}} = Dependencies.new(skill_repository: {String, nil})
  end
end
