defmodule Draught.Session.Settings.Lifecycle do
  @moduledoc """
  Defines optional process ownership and supervisor restart behavior for a session.

  Normal sessions are transient and have no process owner. Temporary interface
  sessions can bind their lifetime to an owner and disable supervisor restarts.
  """

  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @enforce_keys [:owner, :restart]
  defstruct [:owner, :restart]

  @type t :: %__MODULE__{
          owner: pid() | nil,
          restart: :temporary | :transient
        }

  @doc "Builds the session process-ownership and restart contract."
  @spec new(term()) :: Error.result(t())
  def new(attributes \\ []) do
    with {:ok, normalized} <- Attributes.normalize(attributes, [:owner, :restart]),
         {:ok, owner} <- owner_attribute(normalized),
         {:ok, restart} <- restart(normalized) do
      {:ok, %__MODULE__{owner: owner, restart: restart}}
    end
  end

  defp owner(nil) do
    {:ok, nil}
  end

  defp owner(owner) when is_pid(owner) do
    {:ok, owner}
  end

  defp owner(_owner) do
    Error.single([:owner], :invalid_type, "must be a process identifier")
  end

  defp owner_attribute(attributes) do
    attributes
    |> Map.get(:owner)
    |> owner()
  end

  defp restart(attributes) do
    attributes
    |> Map.get(:restart, :transient)
    |> Value.enum([:temporary, :transient], [:restart])
  end
end
