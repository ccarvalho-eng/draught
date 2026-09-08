defmodule Draught.CLI.Interactive.Command.Catalog.Entry do
  @moduledoc """
  Describes one interactive command independently of parsing and presentation.
  """

  @enforce_keys [:argument, :availability, :description, :name, :usage]
  defstruct [:argument, :availability, :description, :name, :usage]

  @type argument :: :none | :optional | :required
  @type availability :: :active | :reserved
  @type t :: %__MODULE__{
          argument: argument(),
          availability: availability(),
          description: String.t(),
          name: atom(),
          usage: String.t()
        }
end
