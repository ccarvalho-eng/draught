defmodule Draught.Provider.Ollama.InventoryTest do
  use ExUnit.Case, async: true

  alias Draught.Error.Normalized
  alias Draught.Provider.Ollama.Configuration
  alias Draught.Provider.Ollama.Discovery.HTTP.Failure
  alias Draught.Provider.Ollama.Discovery.HTTP.Response
  alias Draught.Provider.Ollama.Inventory
  alias Draught.Provider.Ollama.Inventory.Compatible
  alias Draught.Provider.Ollama.Inventory.Incompatible

  defmodule DiscoveryHTTP do
    @behaviour Draught.Provider.Ollama.Discovery.HTTP

    @impl Draught.Provider.Ollama.Discovery.HTTP
    def request(method, url, body, _configuration) do
      send(self(), {:discovery_request, method, url, body})

      receive do
        {:discovery_response, response} -> response
      end
    end
  end

  test "propagates an unavailable discovery service" do
    queue({:error, Failure.new(:unavailable)})

    assert {:error, %Normalized{code: "ollama_unavailable"}} =
             Inventory.list(configuration(), DiscoveryHTTP)
  end

  test "returns an empty inventory when no models are installed" do
    queue_list([])

    assert {:ok, []} = Inventory.list(configuration(), DiscoveryHTTP)
  end

  test "rejects an unbounded installed-model inventory before detail requests" do
    models = Enum.map(1..17, &"model-#{&1}")
    queue_list(models)

    assert {:error, %Normalized{code: "ollama_inventory_too_large"}} =
             Inventory.list(configuration(), DiscoveryHTTP)

    refute_receive {:discovery_request, :post, _url, _body}
  end

  test "returns one typed compatible entry" do
    queue_list(["agent:latest"])
    queue_model(["completion", "tools"])

    assert {:ok, [%Compatible{model: model}]} =
             Inventory.list(configuration(), DiscoveryHTTP)

    assert model.name == "agent:latest"
    assert Inventory.compatible([%Compatible{model: model}]) == [%Compatible{model: model}]
  end

  test "preserves installed order while classifying compatible and incompatible models" do
    queue_list(["chat:latest", "agent:latest", "reasoner:latest"])
    queue_model(["completion"])
    queue_model(["completion", "tools"])
    queue_model(["completion", "thinking"])

    assert {:ok,
            [
              %Incompatible{missing_capabilities: [:tool_calls]},
              %Compatible{},
              %Incompatible{missing_capabilities: [:tool_calls]}
            ] = entries} = Inventory.list(configuration(), DiscoveryHTTP)

    assert Enum.map(entries, & &1.model.name) == [
             "chat:latest",
             "agent:latest",
             "reasoner:latest"
           ]

    compatible_names =
      entries
      |> Inventory.compatible()
      |> Enum.map(& &1.model.name)

    incompatible_names =
      entries
      |> Inventory.incompatible()
      |> Enum.map(& &1.model.name)

    assert compatible_names == ["agent:latest"]

    assert incompatible_names == [
             "chat:latest",
             "reasoner:latest"
           ]
  end

  defp configuration do
    {:ok, configuration} = Configuration.new()
    configuration
  end

  defp queue(response) do
    send(self(), {:discovery_response, response})
  end

  defp queue_list(models) do
    body = Jason.encode!(%{"models" => Enum.map(models, &%{"name" => &1})})
    queue({:ok, %Response{status: 200, body: body}})
  end

  defp queue_model(capabilities) do
    body = Jason.encode!(%{"capabilities" => capabilities, "model_info" => %{}})
    queue({:ok, %Response{status: 200, body: body}})
  end
end
