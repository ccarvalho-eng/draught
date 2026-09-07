defmodule Draught.CLI.Task.Provider.Adapter do
  @moduledoc """
  Constructs a provider selection from resolved trusted CLI configuration.
  """

  alias Draught.CLI.Configuration
  alias Draught.CLI.Task.Provider.Selection

  @type configuration :: term()
  @type result ::
          {:ok, Selection.t()}
          | {:error, Draught.Error.Normalized.t() | Draught.Validation.Error.t()}

  @callback build(Configuration.t(), configuration()) :: result()
end
