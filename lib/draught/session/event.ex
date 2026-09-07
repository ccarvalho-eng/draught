defmodule Draught.Session.Event do
  @moduledoc """
  Defines the messages emitted by a supervised session turn.
  """

  @type turn_id :: pos_integer()
  @type outcome :: Draught.Execution.Runner.result()
  @type t ::
          {:turn_started, turn_id()}
          | {:runner, turn_id(), Draught.Execution.Runner.Event.t()}
          | {:runner, turn_id(), Draught.Execution.Runner.Event.t(), reference()}
          | {:turn_terminal, turn_id(), outcome()}
  @type message :: {:draught_session, String.t(), t()}
end
