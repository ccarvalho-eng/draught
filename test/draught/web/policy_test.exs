defmodule Draught.Web.PolicyTest do
  use ExUnit.Case, async: true

  alias Draught.Validation.Error
  alias Draught.Web.Capability
  alias Draught.Web.Fetch
  alias Draught.Web.Policy
  alias Draught.Web.Search

  defmodule SearchAdapter do
    @behaviour Draught.Web.Search.Adapter

    @impl Draught.Web.Search.Adapter
    def search(_query, _policy, _configuration) do
      {:ok, []}
    end
  end

  defmodule BlockingAdapter do
    @behaviour Draught.Web.Fetch.Adapter
    @behaviour Draught.Web.Search.Adapter

    @impl Draught.Web.Search.Adapter
    def search(_query, _policy, owner) do
      block(owner)
    end

    @impl Draught.Web.Fetch.Adapter
    def fetch(_url, _policy, owner) do
      block(owner)
    end

    defp block(owner) do
      send(owner, {:web_adapter_started, self()})
      Process.sleep(:infinity)
    end
  end

  defmodule CrashingAdapter do
    @behaviour Draught.Web.Fetch.Adapter

    @impl Draught.Web.Fetch.Adapter
    def fetch(_url, _policy, _configuration) do
      exit(:adapter_failed)
    end
  end

  test "keeps both web operations disabled by default" do
    assert {:ok, policy} = Policy.new()
    refute Policy.enabled?(policy, :search)
    refute Policy.enabled?(policy, :fetch)
    assert Policy.status(policy) == %{fetch: :disabled, search: :disabled}

    assert {:ok, capability} = Capability.new()
    refute Capability.enabled?(capability, :search)
    refute Capability.enabled?(capability, :fetch)
  end

  test "resolves global, session, and command overrides in precedence order" do
    global = [search: true, fetch: true, max_response_bytes: 8_192]
    session = [search: false, max_response_bytes: 4_096]
    command = [fetch: false]

    assert {:ok, policy} = Policy.resolve(global, session, command)
    refute Policy.enabled?(policy, :search)
    refute Policy.enabled?(policy, :fetch)
    assert policy.max_response_bytes == 4_096
  end

  test "requires an adapter for every enabled operation" do
    assert {:error, %Error{}} = Capability.new(policy: [search: true])

    assert {:ok, capability} =
             Capability.new(
               policy: [search: true],
               search: {SearchAdapter, :configuration}
             )

    assert Capability.enabled?(capability, :search)
    refute Capability.enabled?(capability, :fetch)
  end

  test "rejects unbounded policy values and unknown layer keys" do
    assert {:error, %Error{}} = Policy.new(max_redirects: 100)
    assert {:error, %Error{}} = Policy.new(max_response_bytes: 0)
    assert {:error, %Error{}} = Policy.resolve([], [unknown: true], [])
  end

  test "enforces the total deadline around search and fetch adapters" do
    {:ok, policy} =
      Policy.new(
        search: true,
        fetch: true,
        request_timeout_ms: 100,
        total_timeout_ms: 100
      )

    capability =
      Capability.new!(
        policy: policy,
        search: {BlockingAdapter, self()},
        fetch: {BlockingAdapter, self()}
      )

    operations = [
      fn -> Search.run(capability, "query", 1_024) end,
      fn -> Fetch.run(capability, "https://example.com", 1_024) end
    ]

    Enum.each(operations, fn operation ->
      started_at = System.monotonic_time(:millisecond)
      assert {:error, error} = operation.()
      assert error.code == "web_timeout"
      assert System.monotonic_time(:millisecond) - started_at < 1_000

      assert_receive {:web_adapter_started, process}, 500
      monitor = Process.monitor(process)
      assert_receive {:DOWN, ^monitor, :process, ^process, :noproc}, 500
    end)
  end

  test "contains a crashing fetch adapter as a recoverable operation failure" do
    capability =
      Capability.new!(
        policy: [fetch: true],
        fetch: {CrashingAdapter, nil}
      )

    assert {:error, error} = Fetch.run(capability, "https://example.com", 1_024)
    assert error.code == "web_request_failed"
    assert Process.alive?(self())
  end
end
