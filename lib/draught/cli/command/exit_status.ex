defmodule Draught.CLI.Command.ExitStatus do
  @moduledoc """
  Stable operating-system exit statuses owned by the command boundary.
  """

  @statuses %{
    success: 0,
    usage: 2,
    provider: 3,
    execution: 4,
    session: 5,
    internal: 70,
    interrupted: 130
  }

  @type category ::
          :success | :usage | :provider | :execution | :session | :internal | :interrupted

  @doc "Returns the stable numeric status for a closed outcome category."
  @spec value(category()) :: non_neg_integer()
  def value(category) when is_map_key(@statuses, category) do
    Map.fetch!(@statuses, category)
  end

  @doc "Returns every stable category-to-status mapping."
  @spec all() :: %{required(category()) => non_neg_integer()}
  def all do
    @statuses
  end
end
