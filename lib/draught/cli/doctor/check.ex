defmodule Draught.CLI.Doctor.Check do
  @moduledoc """
  One deterministic, renderer-independent diagnostic result.
  """

  @enforce_keys [:name, :status, :message]
  defstruct [:name, :status, :message, :hint, details: %{}]

  @type status :: :ok | :error
  @type t :: %__MODULE__{
          name: String.t(),
          status: status(),
          message: String.t(),
          hint: String.t() | nil,
          details: map()
        }

  @doc "Builds a diagnostic check from trusted internal values."
  @spec new(String.t(), status(), String.t(), keyword()) :: t()
  def new(name, status, message, options \\ [])
      when is_binary(name) and status in [:ok, :error] and is_binary(message) do
    %__MODULE__{
      name: name,
      status: status,
      message: message,
      hint: Keyword.get(options, :hint),
      details: Keyword.get(options, :details, %{})
    }
  end
end
