defmodule Draught.CLI.Task.Approval.Prompt do
  @moduledoc """
  Owns one outstanding terminal approval and its revocable reply correlation.

  Sensitive previews are written only to the interactive terminal, never to the
  task event stream. Pending input is invalidated when its requester disappears
  or its deadline expires. Terminal adapters must refuse reuse of abandoned input.
  """

  alias Draught.CLI.Task.Approval.Presentation
  alias Draught.CLI.Task.Approval.Prompt.Pending
  alias Draught.CLI.Task.Stream.Emitter
  alias Draught.Tool.Approval.Request

  @enforce_keys [:scope, :styled?, :terminal]
  defstruct [:scope, :terminal, :pending, styled?: false]

  @type t :: %__MODULE__{
          scope: reference(),
          styled?: boolean(),
          terminal: {module(), term()},
          pending: Pending.t() | nil
        }

  @doc "Builds the terminal side of one fresh invocation's approval channel."
  @spec new(reference(), {module(), term()}, boolean()) :: t()
  def new(scope, terminal, styled? \\ false) do
    %__MODULE__{scope: scope, styled?: styled?, terminal: terminal}
  end

  @doc "Returns the active scope, input reference, and requester monitor for selective receive."
  @spec references(t() | nil) :: {reference() | nil, reference() | nil, reference() | nil}
  def references(%__MODULE__{scope: scope, pending: %Pending{} = pending}) do
    {scope, pending.input, pending.monitor}
  end

  def references(%__MODULE__{scope: scope}) do
    {scope, nil, nil}
  end

  def references(nil) do
    {nil, nil, nil}
  end

  @doc "Bounds the next receive by the current approval's remaining lifetime."
  @spec wait_timeout(t() | nil, non_neg_integer()) :: non_neg_integer()
  def wait_timeout(%__MODULE__{pending: %Pending{deadline: deadline}}, maximum) do
    min(max(deadline - System.monotonic_time(:millisecond), 0), maximum)
  end

  def wait_timeout(_prompt, maximum) do
    maximum
  end

  @doc "Displays a validated operation and starts an asynchronous terminal read."
  @spec request(t(), {pid(), reference(), integer(), Request.t()}, {module(), term()}) ::
          {:ok, t()} | {:error, t()}
  def request(%__MODULE__{pending: nil} = prompt, operation, system) do
    {requester, reference, deadline, request} = operation

    prompt
    |> prepare_operation(requester, deadline, request)
    |> begin_request(prompt, requester, reference, deadline, system)
  end

  def request(%__MODULE__{} = prompt, {requester, reference, _deadline, _request}, _system) do
    reject(prompt, requester, reference)
  end

  @doc "Consumes one matching input record, granting only an explicit timely yes."
  @spec reply(t(), Draught.CLI.Interactive.Terminal.Adapter.input_result()) ::
          {:ok, t()} | {:error, t()}
  def reply(%__MODULE__{pending: %Pending{} = pending} = prompt, {:ok, input}) do
    valid = Pending.live?(pending)
    outcome = outcome(input, valid)
    send_decision(prompt.scope, pending.requester, pending.reference, outcome)
    cleared = clear(prompt)
    reply_result(valid, cleared)
  end

  def reply(%__MODULE__{} = prompt, _input) do
    {:error, close(prompt)}
  end

  @doc "Denies an outstanding operation and invalidates any unread terminal response."
  @spec close(t() | nil) :: t() | nil
  def close(%__MODULE__{pending: %Pending{} = pending} = prompt) do
    {terminal, configuration} = prompt.terminal
    terminal.cancel_read(pending.input, configuration)
    send_decision(prompt.scope, pending.requester, pending.reference, :deny)
    clear(prompt)
  end

  def close(prompt) do
    prompt
  end

  defp begin_request(
         {:ok, validated, presentation},
         prompt,
         requester,
         reference,
         deadline,
         system
       ) do
    with :ok <- Emitter.write(system, :stderr, render(validated, presentation)),
         {:ok, input} <- request_line(prompt.terminal) do
      pending = Pending.new(requester, reference, deadline, input)
      {:ok, %{prompt | pending: pending}}
    else
      _failure -> reject(prompt, requester, reference)
    end
  end

  defp begin_request(
         _unavailable,
         prompt,
         requester,
         reference,
         _deadline,
         _system
       ) do
    reject(prompt, requester, reference)
  end

  defp render(request, presentation) do
    [
      "\nApproval required (25 seconds)\nTool: ",
      request.tool,
      "\nRisk: ",
      Atom.to_string(request.risk),
      "\n",
      presentation,
      "\nApprove this operation once? [y/N] "
    ]
  end

  defp prepare_operation(prompt, requester, deadline, request) do
    with {:ok, validated} <- validate_operation(requester, deadline, request),
         {:ok, presentation} <- Presentation.render(validated, prompt.styled?) do
      {:ok, validated, presentation}
    end
  end

  defp reject(prompt, requester, reference) do
    send_decision(prompt.scope, requester, reference, :deny)
    {:error, prompt}
  end

  defp validate_operation(requester, deadline, request) do
    attributes = Map.from_struct(request)

    with true <- Process.alive?(requester),
         true <- deadline > System.monotonic_time(:millisecond),
         {:ok, validated} <- Request.new(attributes),
         true <- is_binary(validated.preview) do
      {:ok, validated}
    end
  end

  defp request_line({terminal, configuration}) do
    terminal.request_line(configuration)
  end

  defp outcome(input, true) when byte_size(input) <= 16 do
    case String.trim(input) do
      answer when answer in ["y", "Y", "yes", "YES"] -> :allow
      _answer -> :deny
    end
  end

  defp outcome(_input, _valid) do
    :deny
  end

  defp send_decision(scope, requester, reference, outcome) do
    send(requester, {:draught_approval_decision, scope, reference, outcome})
    :ok
  end

  defp clear(%__MODULE__{pending: %Pending{monitor: monitor}} = prompt) do
    Process.demonitor(monitor, [:flush])
    %{prompt | pending: nil}
  end

  defp reply_result(true, prompt) do
    {:ok, prompt}
  end

  defp reply_result(false, prompt) do
    {:error, prompt}
  end
end
