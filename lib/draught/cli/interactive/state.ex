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
    :workspace,
    persisted?: false,
    phase: :idle
  ]

  @type phase :: :idle | :running | :awaiting_approval | :stopping | :stopped
  @type t :: %__MODULE__{
          active_prompt: String.t() | nil,
          approval_id: String.t() | nil,
          model: String.t(),
          persisted?: boolean(),
          phase: phase(),
          provider: String.t(),
          queued_prompt: String.t() | nil,
          session_id: String.t(),
          session_label: String.t(),
          web: boolean(),
          workspace: String.t()
        }

  @doc "Builds an idle session state from trusted, display-safe context."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes) do
    keys = [:model, :provider, :session_id, :session_label, :web, :workspace]

    with {:ok, normalized} <- Attributes.normalize(attributes, keys) do
      build(normalized)
    end
  end

  @doc "Begins a turn only while the shell is idle."
  @spec start_turn(t(), String.t()) :: {:ok, t()} | {:error, :busy | :invalid_prompt}
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
    with {:ok, model} <- Value.required_string(attributes, :model),
         {:ok, provider} <- Value.required_string(attributes, :provider),
         {:ok, session_id} <- Value.required_string(attributes, :session_id) do
      build_session(attributes, model, provider, session_id)
    end
  end

  defp build_session(attributes, model, provider, session_id) do
    with {:ok, session_label} <- session_label(attributes, session_id),
         {:ok, web} <- required_boolean(attributes, :web),
         {:ok, workspace} <- Value.required_string(attributes, :workspace) do
      {:ok,
       %__MODULE__{
         model: model,
         provider: provider,
         session_id: session_id,
         session_label: session_label,
         web: web,
         workspace: workspace
       }}
    end
  end

  defp required_boolean(attributes, key) do
    with {:ok, value} <- Attributes.fetch_required(attributes, key) do
      Value.boolean(value, [key])
    end
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
