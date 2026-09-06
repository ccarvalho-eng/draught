defmodule Draught.Provider.Fake.Stream do
  @moduledoc """
  An exact request-to-nonterminal-event-sequence route for the deterministic fake provider.
  """

  alias Draught.Event
  alias Draught.Event.Provider.Delta
  alias Draught.Event.Provider.ToolCall
  alias Draught.Provider.Fake.Completion
  alias Draught.Provider.Request
  alias Draught.Validation
  alias Draught.Validation.Attributes

  @enforce_keys [:request, :events, :result]
  defstruct [:request, :events, :result]

  @type t :: %__MODULE__{
          request: Request.t(),
          events: [Delta.t() | ToolCall.t()],
          result: Completion.result()
        }

  @doc "Builds a stream route from nonterminal events and one final result."
  @spec new(map() | keyword()) :: Validation.result(t())
  def new(attributes) do
    with {:ok, normalized} <-
           Attributes.normalize(attributes, [:request, :events, :response, :error, :result]),
         {:ok, request} <- request(normalized),
         {:ok, events} <- events(normalized),
         {:ok, result} <- result(normalized) do
      {:ok, %__MODULE__{request: request, events: events, result: result}}
    end
  end

  defp request(attributes) do
    with {:ok, value} <- Attributes.fetch_required(attributes, :request) do
      case value do
        %Request{} = request ->
          request
          |> Map.from_struct()
          |> Request.new()

        external ->
          Request.new(external)
      end
    end
  end

  defp events(attributes) do
    with {:ok, values} <- Attributes.fetch_required(attributes, :events) do
      normalize_events(values)
    end
  end

  defp normalize_events(values) when is_list(values) do
    values
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {value, index}, {:ok, valid_events} ->
      case normalize_event(value) do
        {:ok, event} -> {:cont, {:ok, [event | valid_events]}}
        {:error, error} -> {:halt, {:error, prefix_error(error, [:events, index])}}
      end
    end)
    |> reverse_events()
  end

  defp normalize_events(_values) do
    Validation.error([:events], :invalid_type, "must be a list")
  end

  defp normalize_event(value) when is_struct(value) do
    value
    |> Event.validate()
    |> ensure_nonterminal()
  end

  defp normalize_event(value) do
    value
    |> Event.new()
    |> ensure_nonterminal()
  end

  defp result(attributes) do
    attributes
    |> Map.take([:request, :response, :error, :result])
    |> Completion.new()
    |> unwrap_completion()
  end

  defp unwrap_completion({:ok, %Completion{result: result}}) do
    {:ok, result}
  end

  defp unwrap_completion({:error, _error} = result) do
    result
  end

  defp ensure_nonterminal({:ok, event})
       when is_struct(event, Delta) or is_struct(event, ToolCall) do
    {:ok, event}
  end

  defp ensure_nonterminal({:ok, _event}) do
    Validation.error([], :invalid_relationship, "must contain only nonterminal events")
  end

  defp ensure_nonterminal({:error, _error} = result) do
    result
  end

  defp reverse_events({:ok, events}) do
    {:ok, Enum.reverse(events)}
  end

  defp reverse_events({:error, _error} = result) do
    result
  end

  defp prefix_error(%{violations: violations}, prefix) do
    prefixed =
      Enum.map(violations, fn violation ->
        %{violation | path: prefix ++ violation.path}
      end)

    Validation.new_error(prefixed)
  end
end
