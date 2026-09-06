defmodule Draught.Provider.Fake do
  @moduledoc """
  A pure deterministic provider for tests, examples, and offline development.

  Routes use exact canonical request equality. The fake owns no process and no
  global state, so callers inject the returned value as `{Draught.Provider.Fake, fake}`.
  """

  @behaviour Draught.Provider

  alias Draught.Error.Normalized
  alias Draught.Provider.Capabilities
  alias Draught.Provider.Fake.Completion
  alias Draught.Provider.Fake.Stream
  alias Draught.Validation
  alias Draught.Validation.Attributes

  @enforce_keys [:capabilities, :completions, :streams]
  defstruct [:capabilities, :completions, :streams]

  @type t :: %__MODULE__{
          capabilities: Capabilities.t(),
          completions: [Completion.t()],
          streams: [Stream.t()]
        }

  @doc "Builds a fake from explicit completion and stream routes."
  @spec new(map() | keyword()) :: Validation.result(t())
  def new(attributes \\ %{}) do
    with {:ok, normalized} <-
           Attributes.normalize(attributes, [:capabilities, :completions, :streams]),
         {:ok, capabilities} <- normalize_capabilities(normalized),
         {:ok, completions} <- routes(normalized, :completions, Completion),
         :ok <- unique_requests(completions, :completions),
         {:ok, streams} <- routes(normalized, :streams, Stream),
         :ok <- unique_requests(streams, :streams) do
      {:ok,
       %__MODULE__{
         capabilities: capabilities,
         completions: completions,
         streams: streams
       }}
    end
  end

  @impl Draught.Provider
  def capabilities(%__MODULE__{capabilities: capabilities}) do
    {:ok, capabilities}
  end

  @impl Draught.Provider
  def complete(request, %__MODULE__{completions: routes}) do
    case Enum.find(routes, &(&1.request == request)) do
      %Completion{result: result} -> result
      nil -> missing_route(:completion)
    end
  end

  @impl Draught.Provider
  def stream(request, %__MODULE__{streams: routes}, sink) do
    case Enum.find(routes, &(&1.request == request)) do
      %Stream{} = route -> emit(route, sink)
      nil -> missing_route(:stream)
    end
  end

  defp normalize_capabilities(attributes) do
    defaults = [chat: true, streaming: true, tool_calls: true, reasoning: true, usage: true]

    case Map.get(attributes, :capabilities, defaults) do
      %Capabilities{} = capabilities ->
        capabilities
        |> Map.from_struct()
        |> Capabilities.new()

      external ->
        Capabilities.new(external)
    end
  end

  defp routes(attributes, key, module) do
    case Map.get(attributes, key, []) do
      values when is_list(values) -> normalize_routes(values, key, module)
      _values -> Validation.error([key], :invalid_type, "must be a list")
    end
  end

  defp normalize_routes(values, key, module) do
    values
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {value, index}, {:ok, routes} ->
      case normalize_route(value, module) do
        {:ok, route} -> {:cont, {:ok, [route | routes]}}
        {:error, error} -> {:halt, {:error, prefix_error(error, [key, index])}}
      end
    end)
    |> reverse_routes()
  end

  defp normalize_route(%{__struct__: module} = route, module) do
    route
    |> Map.from_struct()
    |> module.new()
  end

  defp normalize_route(attributes, module) do
    module.new(attributes)
  end

  defp reverse_routes({:ok, routes}) do
    {:ok, Enum.reverse(routes)}
  end

  defp reverse_routes({:error, _error} = result) do
    result
  end

  defp unique_requests(routes, key) do
    requests = Enum.map(routes, & &1.request)

    requests
    |> unique?()
    |> unique_requests_result(key)
  end

  defp unique?(values) do
    unique_count =
      values
      |> MapSet.new()
      |> MapSet.size()

    unique_count == length(values)
  end

  defp unique_requests_result(true, _key) do
    :ok
  end

  defp unique_requests_result(false, key) do
    Validation.error([key], :invalid_relationship, "must have unique requests")
  end

  defp emit(%Stream{events: events, result: result}, sink) do
    Enum.reduce_while(events, result, fn event, _result ->
      case sink.(event) do
        :ok -> {:cont, result}
        :halt -> {:halt, cancellation()}
      end
    end)
  end

  defp missing_route(route_type) do
    {:ok, error} =
      Normalized.new(
        :configuration,
        "fake_route_not_found",
        "fake provider has no matching #{route_type} route",
        retryable: false
      )

    {:error, error}
  end

  defp cancellation do
    {:ok, error} =
      Normalized.new(
        :cancellation,
        "stream_cancelled",
        "stream sink requested cancellation",
        retryable: false
      )

    {:error, error}
  end

  defp prefix_error(%{violations: violations}, prefix) do
    prefixed =
      Enum.map(violations, fn violation ->
        %{violation | path: prefix ++ violation.path}
      end)

    Validation.new_error(prefixed)
  end
end
