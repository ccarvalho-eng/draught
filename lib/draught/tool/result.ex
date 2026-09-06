defmodule Draught.Tool.Result do
  @moduledoc """
  A provider-neutral result returned for one tool call.
  """

  alias Draught.Error.Normalized
  alias Draught.Tool.Name
  alias Draught.Validation
  alias Draught.Validation.Attributes
  alias Draught.Validation.Value

  @error_kinds [:cancellation, :policy, :timeout, :tool]
  @statuses [:error, :success]

  @enforce_keys [:call_id, :name, :content, :status]
  defstruct [:call_id, :name, :content, :status, :error]

  @type status :: :error | :success
  @type t :: %__MODULE__{
          call_id: String.t(),
          name: String.t(),
          content: String.t(),
          status: status(),
          error: Normalized.t() | nil
        }

  @doc "Builds a validated tool result from external attributes."
  @spec new(map() | keyword()) :: Validation.result(t())
  def new(attributes) do
    with {:ok, normalized} <-
           Attributes.normalize(attributes, [:call_id, :name, :content, :status, :error]) do
      normalize_result(normalized)
    end
  end

  defp normalize_result(attributes) do
    with {:ok, call_id, name} <- identity(attributes),
         {:ok, content, status, error} <- outcome(attributes) do
      {:ok,
       %__MODULE__{
         call_id: call_id,
         name: name,
         content: content,
         status: status,
         error: error
       }}
    end
  end

  defp identity(attributes) do
    with {:ok, call_id} <- Value.required_string(attributes, :call_id),
         {:ok, raw_name} <- Attributes.fetch_required(attributes, :name),
         {:ok, name} <- Name.validate(raw_name) do
      {:ok, call_id, name}
    end
  end

  defp outcome(attributes) do
    with {:ok, content} <- required_content(attributes),
         {:ok, status} <- status(attributes),
         {:ok, error} <- execution_error(attributes),
         :ok <- validate_relationship(status, error) do
      {:ok, content, status, error}
    end
  end

  defp required_content(attributes) do
    with {:ok, content} <- Attributes.fetch_required(attributes, :content) do
      Value.string(content, [:content], allow_empty: true)
    end
  end

  defp status(attributes) do
    attributes
    |> Map.get(:status, :success)
    |> Value.enum(@statuses, [:status])
  end

  defp execution_error(attributes) do
    case Map.get(attributes, :error) do
      nil ->
        {:ok, nil}

      %Normalized{} = error ->
        error
        |> Map.from_struct()
        |> Normalized.new()

      error when is_map(error) or is_list(error) ->
        Normalized.new(error)

      _error ->
        Validation.error([:error], :invalid_type, "must be a normalized error")
    end
  end

  defp validate_relationship(:success, nil) do
    :ok
  end

  defp validate_relationship(:error, %Normalized{kind: kind}) when kind in @error_kinds do
    :ok
  end

  defp validate_relationship(:success, %Normalized{}) do
    Validation.error(
      [:error],
      :invalid_relationship,
      "must be absent for a successful result"
    )
  end

  defp validate_relationship(:error, nil) do
    Validation.error([:error], :required, "is required for an error result")
  end

  defp validate_relationship(:error, %Normalized{}) do
    Validation.error(
      [:error, :kind],
      :invalid_relationship,
      "must describe a tool execution failure"
    )
  end
end
