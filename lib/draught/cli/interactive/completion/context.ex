defmodule Draught.CLI.Interactive.Completion.Context do
  @moduledoc """
  Holds the bounded, effect-free values available to one completion callback.

  Provider and session lookups occur before this snapshot is built; pressing
  Tab never performs network, filesystem, or process work.
  """

  alias Draught.CLI.Interactive.Command.Catalog
  alias Draught.CLI.Interactive.State

  @enforce_keys [:commands, :models, :skills]
  defstruct [:commands, :models, :skills]

  @type t :: %__MODULE__{
          commands: [String.t()],
          models: [String.t()],
          skills: [String.t()]
        }

  @doc "Builds one completion snapshot from validated interactive state."
  @spec from_state(State.t()) :: t()
  def from_state(%State{} = state) do
    commands = Enum.map(Catalog.all(), &("/" <> Atom.to_string(&1.name)))

    %__MODULE__{
      commands: commands,
      models: state.model_catalog,
      skills: state.skill_catalog
    }
  end
end
