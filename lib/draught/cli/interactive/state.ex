defmodule Draught.CLI.Interactive.State do
  @moduledoc """
  Defines pure lifecycle transitions for one interactive CLI session.

  The state machine records display-safe session context separately from active
  turn, approval, queue, and shutdown state. Effectful controllers interpret
  returned actions but cannot bypass these transitions.
  """

  alias Draught.CLI.Session.Catalog.Name
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @enforce_keys [:model, :provider, :session_id, :session_label, :web, :workspace]
  defstruct [
    :active_prompt,
    :approval_id,
    :model,
    :provider,
    :queued_prompt,
    :session_id,
    :session_label,
    :web,
    :web_search,
    :workspace,
    model_catalog: [],
    model_catalog_displayed?: false,
    persisted?: false,
    phase: :idle
  ]

  @type phase :: :idle | :running | :awaiting_approval | :stopping | :stopped
  @type t :: %__MODULE__{
          active_prompt: String.t() | nil,
          approval_id: String.t() | nil,
          model: String.t() | nil,
          model_catalog: [String.t()],
          model_catalog_displayed?: boolean(),
          persisted?: boolean(),
          phase: phase(),
          provider: String.t(),
          queued_prompt: String.t() | nil,
          session_id: String.t(),
          session_label: String.t(),
          web: boolean(),
          web_search: boolean(),
          workspace: String.t()
        }

  @doc "Builds an idle session state from trusted, display-safe context."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes) do
    keys = [
      :model,
      :model_catalog,
      :provider,
      :session_id,
      :session_label,
      :web,
      :web_search,
      :workspace
    ]

    with {:ok, normalized} <- Attributes.normalize(attributes, keys) do
      build(normalized)
    end
  end

  @doc "Begins a turn only while the shell is idle."
  @spec start_turn(t(), String.t()) ::
          {:ok, t()} | {:error, :busy | :invalid_prompt | :model_required}
  def start_turn(%__MODULE__{model: nil}, _prompt) do
    {:error, :model_required}
  end

  def start_turn(%__MODULE__{phase: :idle} = state, prompt) do
    case prompt(prompt) do
      {:ok, validated} ->
        {:ok, %{state | active_prompt: validated, phase: :running}}

      :error ->
        {:error, :invalid_prompt}
    end
  end

  def start_turn(%__MODULE__{}, _prompt) do
    {:error, :busy}
  end

  @doc "Queues one explicit next turn while work is active."
  @spec queue_prompt(t(), String.t()) ::
          {:ok, t()} | {:error, :idle | :invalid_prompt | :queue_full}
  def queue_prompt(%__MODULE__{phase: phase, queued_prompt: nil} = state, prompt)
      when phase in [:running, :awaiting_approval] do
    case prompt(prompt) do
      {:ok, validated} -> {:ok, %{state | queued_prompt: validated}}
      :error -> {:error, :invalid_prompt}
    end
  end

  def queue_prompt(%__MODULE__{phase: phase}, _prompt)
      when phase in [:running, :awaiting_approval] do
    {:error, :queue_full}
  end

  def queue_prompt(%__MODULE__{}, _prompt) do
    {:error, :idle}
  end

  @doc "Completes a turn and either becomes idle or starts its queued successor."
  @spec finish_turn(t(), boolean()) ::
          {:idle, t()} | {:next, t(), String.t()} | {:error, :not_running}
  def finish_turn(%__MODULE__{phase: :running, queued_prompt: nil} = state, persisted?)
      when is_boolean(persisted?) do
    updated = %{
      state
      | active_prompt: nil,
        persisted?: state.persisted? or persisted?,
        phase: :idle
    }

    {:idle, updated}
  end

  def finish_turn(%__MODULE__{phase: :running, queued_prompt: queued} = state, persisted?)
      when is_binary(queued) and is_boolean(persisted?) do
    updated = %{
      state
      | active_prompt: queued,
        persisted?: state.persisted? or persisted?,
        queued_prompt: nil
    }

    {:next, updated, queued}
  end

  def finish_turn(%__MODULE__{}, _persisted?) do
    {:error, :not_running}
  end

  @doc "Moves a running turn into an approval wait with one opaque identifier."
  @spec request_approval(t(), String.t()) ::
          {:ok, t()} | {:error, :invalid_approval | :not_running}
  def request_approval(%__MODULE__{phase: :running} = state, approval_id) do
    case prompt(approval_id) do
      {:ok, validated} ->
        {:ok, %{state | approval_id: validated, phase: :awaiting_approval}}

      :error ->
        {:error, :invalid_approval}
    end
  end

  def request_approval(%__MODULE__{}, _approval_id) do
    {:error, :not_running}
  end

  @doc "Returns an approval wait to its active turn only for the current identifier."
  @spec resolve_approval(t(), String.t()) ::
          {:ok, t()} | {:error, :not_awaiting_approval | :stale_approval}
  def resolve_approval(
        %__MODULE__{phase: :awaiting_approval, approval_id: approval_id} = state,
        approval_id
      ) do
    {:ok, %{state | approval_id: nil, phase: :running}}
  end

  def resolve_approval(%__MODULE__{phase: :awaiting_approval}, _approval_id) do
    {:error, :stale_approval}
  end

  def resolve_approval(%__MODULE__{}, _approval_id) do
    {:error, :not_awaiting_approval}
  end

  @doc "Maps interruption to cancellation first and a stable interrupted exit second."
  @spec interrupt(t()) :: {:cancel, t()} | {:exit, 130, t()}
  def interrupt(%__MODULE__{phase: phase} = state)
      when phase in [:running, :awaiting_approval] do
    {:cancel, %{state | approval_id: nil, phase: :stopping}}
  end

  def interrupt(%__MODULE__{phase: :stopping} = state) do
    {:exit, 130, %{state | phase: :stopped}}
  end

  def interrupt(%__MODULE__{} = state) do
    {:exit, 130, %{state | phase: :stopped}}
  end

  @doc "Marks a loaded session as already persisted without changing its phase."
  @spec persisted(t()) :: t()
  def persisted(%__MODULE__{} = state) do
    %{state | persisted?: true}
  end

  @doc "Checks whether the active session may change its model binding."
  @spec model_selectable(t()) :: :ok | {:error, :busy | :persisted_model}
  def model_selectable(%__MODULE__{persisted?: true}) do
    {:error, :persisted_model}
  end

  def model_selectable(%__MODULE__{phase: :idle}) do
    :ok
  end

  def model_selectable(%__MODULE__{}) do
    {:error, :busy}
  end

  @doc "Selects a model only before an idle session establishes durable state."
  @spec select_model(t(), term()) ::
          {:ok, t()} | {:error, :busy | :invalid_model | :persisted_model}
  def select_model(%__MODULE__{} = state, model) do
    with :ok <- model_selectable(state),
         {:ok, validated} <- required_model(model) do
      {:ok, %{state | model: validated}}
    end
  end

  @doc "Retains the bounded model inventory most recently shown to the user."
  @spec display_models(t(), term()) :: {:ok, t()} | {:error, :invalid_model_catalog}
  def display_models(%__MODULE__{} = state, models) do
    case validate_model_catalog(models) do
      {:ok, validated} ->
        {:ok, %{state | model_catalog: validated, model_catalog_displayed?: true}}

      {:error, _error} ->
        {:error, :invalid_model_catalog}
    end
  end

  @doc "Returns the last model inventory shown by the shell."
  @spec displayed_models(t()) :: {:ok, [String.t()]} | {:error, :model_list_required}
  def displayed_models(%__MODULE__{model_catalog_displayed?: true, model_catalog: models}) do
    {:ok, models}
  end

  def displayed_models(%__MODULE__{}) do
    {:error, :model_list_required}
  end

  @doc "Selects a prepared idle session without carrying transient turn state."
  @spec select(t(), t()) :: {:ok, t()} | {:error, :busy}
  def select(%__MODULE__{phase: :idle}, %__MODULE__{phase: :idle} = selected) do
    {:ok, selected}
  end

  def select(%__MODULE__{}, %__MODULE__{}) do
    {:error, :busy}
  end

  @doc "Changes the display label of an idle session."
  @spec rename(t(), String.t()) :: {:ok, t()} | {:error, :busy | :invalid_label}
  def rename(%__MODULE__{phase: :idle} = state, label) do
    case Name.validate(label) do
      {:ok, validated} -> {:ok, %{state | session_label: validated}}
      {:error, _error} -> {:error, :invalid_label}
    end
  end

  def rename(%__MODULE__{}, _label) do
    {:error, :busy}
  end

  defp build(attributes) do
    with {:ok, model} <- optional_model(attributes),
         {:ok, model_catalog} <- model_catalog(attributes),
         {:ok, provider} <- Value.required_string(attributes, :provider),
         {:ok, session_id} <- Value.required_string(attributes, :session_id) do
      build_session(attributes, model, model_catalog, provider, session_id)
    end
  end

  defp model_catalog(attributes) do
    attributes
    |> Map.get(:model_catalog, [])
    |> validate_model_catalog()
  end

  defp validate_model_catalog(models) when is_list(models) do
    bounded = Enum.count_until(models, 17) <= 16

    valid =
      Enum.all?(models, fn model ->
        is_binary(model) and byte_size(model) > 0 and byte_size(model) <= 256 and
          String.valid?(model) and not String.contains?(model, <<0>>)
      end)

    unique = Enum.uniq(models) == models
    model_catalog_result(bounded and valid and unique, models)
  end

  defp validate_model_catalog(_models) do
    model_catalog_result(false, [])
  end

  defp model_catalog_result(true, models) do
    {:ok, models}
  end

  defp model_catalog_result(false, _models) do
    Error.single(
      [:model_catalog],
      :invalid_value,
      "must contain at most 16 unique bounded UTF-8 model names"
    )
  end

  defp optional_model(attributes) do
    with {:ok, value} <- Attributes.fetch_required(attributes, :model) do
      optional_model_value(value)
    end
  end

  defp optional_model_value(nil) do
    {:ok, nil}
  end

  defp optional_model_value(value) do
    Value.required_string(%{model: value}, :model)
  end

  defp required_model(value) do
    case Value.required_string(%{model: value}, :model) do
      {:ok, model} -> {:ok, model}
      {:error, _error} -> {:error, :invalid_model}
    end
  end

  defp build_session(attributes, model, model_catalog, provider, session_id) do
    with {:ok, session_label} <- session_label(attributes, session_id),
         {:ok, web} <- required_boolean(attributes, :web),
         {:ok, web_search} <- optional_boolean(attributes, :web_search),
         {:ok, workspace} <- Value.required_string(attributes, :workspace) do
      {:ok,
       %__MODULE__{
         model: model,
         model_catalog: model_catalog,
         provider: provider,
         session_id: session_id,
         session_label: session_label,
         web: web,
         web_search: web_search,
         workspace: workspace
       }}
    end
  end

  defp required_boolean(attributes, key) do
    with {:ok, value} <- Attributes.fetch_required(attributes, key) do
      Value.boolean(value, [key])
    end
  end

  defp optional_boolean(attributes, key) do
    attributes
    |> Map.get(key, false)
    |> Value.boolean([key])
  end

  defp session_label(attributes, identifier) do
    attributes
    |> Map.get(:session_label, identifier)
    |> Value.string([:session_label])
  end

  defp prompt(value) when is_binary(value) and byte_size(value) > 0 do
    valid = String.valid?(value) and byte_size(value) <= 65_536
    prompt_result(valid, value)
  end

  defp prompt(_value) do
    :error
  end

  defp prompt_result(true, value) do
    {:ok, value}
  end

  defp prompt_result(false, _value) do
    :error
  end
end
