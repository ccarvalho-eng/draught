defmodule Draught.CLI.Task.Provider.Failure do
  @moduledoc false

  alias Draught.Error.Normalized

  @doc "Builds the bounded failure for an invalid provider-factory result."
  @spec invalid_selection() :: Normalized.t()
  def invalid_selection do
    {:ok, error} =
      Normalized.new(
        :protocol,
        "invalid_provider_selection",
        "Provider factory returned an invalid selection",
        retryable: false
      )

    error
  end
end
