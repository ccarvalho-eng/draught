defmodule Draught.CLI.Session.Store.Handle do
  @moduledoc false

  alias Draught.CLI.Session.Store.Lease
  alias Draught.CLI.Session.Store.Paths

  @enforce_keys [:lease, :mode, :paths]
  defstruct [:lease, :mode, :paths]

  @type t :: %__MODULE__{
          lease: Lease.t(),
          mode: :create | :resume,
          paths: Paths.t()
        }
end
