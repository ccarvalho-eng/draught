defmodule Draught.CLI.Task.Approval.Prompt do
  @moduledoc """
  Owns one outstanding terminal approval and its revocable reply correlation.

  Sensitive previews are written only to the interactive terminal, never to the
  task event stream. Pending input is invalidated when its requester disappears
  or its deadline expires. Terminal adapters must refuse reuse of abandoned input.
  """

  alias Draught.CLI.Task.Approval.Prompt.Pending
  alias Draught.CLI.Task.Stream.Emitter
  alias Draught.Tool.Approval.Request

  @enforce_keys [:scope, :terminal]
  defstruct [:scope, :terminal, :pending]

  @type t :: %__MODULE__{
          scope: reference(),
          terminal: {module(), term()},
          pending: Pending.t() | nil
        }

  @doc "Builds the terminal side of one fresh invocation's approval channel."
  @spec new(reference(), {module(), term()}) :: t()
  def new(scope, terminal) do
    %__MODULE__{scope: scope, terminal: terminal}
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

    with {:ok, validated} <- validate_operation(requester, deadline, request),
         :ok <- Emitter.write(system, :stderr, render(validated)),
         {:ok, input} <- request_line(prompt.terminal) do
      pending = Pending.new(requester, reference, deadline, input)
      {:ok, %{prompt | pending: pending}}
    else
      _failure ->
        send_decision(prompt.scope, requester, reference, :deny)
        {:error, prompt}
    end
  end

  def request(%__MODULE__{} = prompt, {requester, reference, _deadline, _request}, _system) do
    send_decision(prompt.scope, requester, reference, :deny)
    {:error, prompt}
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

  defp render(request) do
    [
      "\nApproval required (25 seconds)\nTool: ",
      request.tool,
      "\nRisk: ",
      Atom.to_string(request.risk),
      "\nOperation (escaped JSON):\n",
      request.preview,
      "\nApprove this operation once? [y/N] "
    ]
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
