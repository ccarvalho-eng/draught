defmodule Draught.CLI.Task.Preparation.Web do
  @moduledoc """
  Constructs the trusted web capability selected by CLI configuration.

  Disabled tasks receive no web adapters. Enabled tasks receive only the
  guarded fetch transport until a concrete search adapter is configured.
  """

  alias Draught.Validation.Error
  alias Draught.Web.Capability
  alias Draught.Web.Fetch.Transport.Mint

  @doc "Builds the effective CLI web capability from a validated setting."
  @spec capability(boolean()) :: Error.result(Capability.t())
  def capability(false) do
    Capability.new()
  end

  def capability(true) do
    Capability.new(
      policy: [fetch: true],
      fetch: {Mint, []}
    )
  end
end
