defmodule Draught.Session.Journal.Adapter do
  @moduledoc """
  Defines the persistence boundary for versioned session journals.
  """

  @type configuration :: term()
  @type handle :: term()
  @type error :: Draught.Error.Normalized.t() | Draught.Validation.Error.t()

  @callback open(configuration()) ::
              {:ok, handle(), Draught.Session.Journal.Replay.t()} | {:error, error()}
  @callback append(handle(), Draught.Session.Journal.Event.t()) ::
              {:ok, handle()} | {:error, error()}
  @callback checkpoint(handle()) :: {:ok, handle()} | {:error, error()}
  @callback replay(configuration()) ::
              {:ok, Draught.Session.Journal.Replay.t()} | {:error, error()}
end
