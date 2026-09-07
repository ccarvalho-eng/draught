defmodule Draught.Session.Journal.Local.Configuration do
  @moduledoc """
  Validated configuration for one workspace-local session journal.
  """

  alias Draught.Session.Journal.Local.Paths
  alias Draught.Session.Journal.Retention
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error

  @enforce_keys [:clock, :paths, :retention]
  defstruct [:clock, :paths, :retention]

  @type clock :: (-> DateTime.t())
  @type t :: %__MODULE__{clock: clock(), paths: term(), retention: Retention.t()}

  @doc "Builds local journal configuration from workspace, identifier, and policy."
  @spec new(term(), term(), map() | keyword()) :: Error.result(t())
  def new(workspace, identifier, options \\ []) do
    with {:ok, normalized} <- Attributes.normalize(options, [:clock, :retention]),
         {:ok, paths} <- Paths.new(workspace, identifier),
         {:ok, clock} <- clock(normalized),
         {:ok, retention} <- retention(normalized) do
      {:ok, %__MODULE__{clock: clock, paths: paths, retention: retention}}
    end
  end

  defp clock(attributes) do
    value = Map.get(attributes, :clock, &DateTime.utc_now/0)

    value
    |> is_function(0)
    |> clock_result(value)
  end

  defp retention(attributes) do
    case Map.get(attributes, :retention, []) do
      %Retention{} = retention ->
        retention
        |> Map.from_struct()
        |> Retention.new()

      value ->
        Retention.new(value)
    end
  end

  defp clock_result(true, value) do
    {:ok, value}
  end

  defp clock_result(false, _value) do
    Error.single([:clock], :invalid_type, "must be a zero-arity function")
  end
end
