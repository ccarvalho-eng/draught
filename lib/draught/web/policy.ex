defmodule Draught.Web.Policy do
  @moduledoc """
  Immutable web permissions and resource limits.

  Both operations are disabled unless an interface resolves an explicit setting.
  Resolution applies global, session, then command values in increasing precedence.
  """

  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @keys [
    :search,
    :fetch,
    :max_redirects,
    :max_response_bytes,
    :max_search_results,
    :request_timeout_ms,
    :total_timeout_ms
  ]
  @maximum_redirects 10
  @maximum_response_bytes 8 * 1024 * 1024
  @maximum_search_results 20
  @maximum_timeout_ms 120_000

  defstruct search: false,
            fetch: false,
            max_redirects: 3,
            max_response_bytes: 1024 * 1024,
            max_search_results: 10,
            request_timeout_ms: 10_000,
            total_timeout_ms: 30_000

  @type operation :: :search | :fetch
  @type t :: %__MODULE__{
          search: boolean(),
          fetch: boolean(),
          max_redirects: non_neg_integer(),
          max_response_bytes: pos_integer(),
          max_search_results: pos_integer(),
          request_timeout_ms: pos_integer(),
          total_timeout_ms: pos_integer()
        }

  @doc "Builds a web policy with disabled defaults and bounded limits."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes \\ %{}) do
    with {:ok, normalized} <- Attributes.normalize(attributes, @keys),
         {:ok, permissions} <- permissions(normalized),
         {:ok, limits} <- limits(normalized),
         :ok <- timeout_order(limits.request_timeout_ms, limits.total_timeout_ms) do
      {:ok, struct!(__MODULE__, Map.merge(permissions, limits))}
    end
  end

  @doc "Resolves global, session, and command layers into one effective policy."
  @spec resolve(map() | keyword(), map() | keyword(), map() | keyword()) :: Error.result(t())
  def resolve(global, session \\ [], command \\ []) do
    with {:ok, global_layer} <- layer(global),
         {:ok, session_layer} <- layer(session),
         {:ok, command_layer} <- layer(command) do
      global_layer
      |> Map.merge(session_layer)
      |> Map.merge(command_layer)
      |> new()
    end
  end

  @doc "Returns whether one web operation is enabled."
  @spec enabled?(t(), operation()) :: boolean()
  def enabled?(%__MODULE__{search: enabled}, :search) do
    enabled
  end

  def enabled?(%__MODULE__{fetch: enabled}, :fetch) do
    enabled
  end

  @doc "Projects the effective permissions for interface status rendering."
  @spec status(t()) :: %{fetch: :disabled | :enabled, search: :disabled | :enabled}
  def status(%__MODULE__{} = policy) do
    %{fetch: state(policy.fetch), search: state(policy.search)}
  end

  defp permissions(attributes) do
    with {:ok, search} <- boolean(attributes, :search, false),
         {:ok, fetch} <- boolean(attributes, :fetch, false) do
      {:ok, %{fetch: fetch, search: search}}
    end
  end

  defp limits(attributes) do
    with {:ok, redirects} <- redirects(attributes),
         {:ok, response_bytes} <-
           bounded(attributes, :max_response_bytes, 1024 * 1024, @maximum_response_bytes),
         {:ok, results} <- bounded(attributes, :max_search_results, 10, @maximum_search_results),
         {:ok, request_timeout} <-
           bounded(attributes, :request_timeout_ms, 10_000, @maximum_timeout_ms),
         {:ok, total_timeout} <-
           bounded(attributes, :total_timeout_ms, 30_000, @maximum_timeout_ms) do
      {:ok,
       %{
         max_redirects: redirects,
         max_response_bytes: response_bytes,
         max_search_results: results,
         request_timeout_ms: request_timeout,
         total_timeout_ms: total_timeout
       }}
    end
  end

  defp layer(attributes) do
    Attributes.normalize(attributes, @keys)
  end

  defp boolean(attributes, key, default) do
    attributes
    |> Map.get(key, default)
    |> Value.boolean([key])
  end

  defp redirects(attributes) do
    value = Map.get(attributes, :max_redirects, 3)
    redirect_result(value)
  end

  defp redirect_result(value)
       when is_integer(value) and value >= 0 and value <= @maximum_redirects do
    {:ok, value}
  end

  defp redirect_result(_value) do
    Error.single([:max_redirects], :invalid_value, "must be from 0 to #{@maximum_redirects}")
  end

  defp bounded(attributes, key, default, maximum) do
    attributes
    |> Map.get(key, default)
    |> Value.positive_integer_at_most(maximum, [key])
  end

  defp timeout_order(request_timeout, total_timeout) when request_timeout <= total_timeout do
    :ok
  end

  defp timeout_order(_request_timeout, _total_timeout) do
    Error.single([:request_timeout_ms], :invalid_relationship, "must not exceed total timeout")
  end

  defp state(true) do
    :enabled
  end

  defp state(false) do
    :disabled
  end
end
