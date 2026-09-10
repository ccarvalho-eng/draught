defmodule Draught.CLI.Task.Stream.Renderer.Interactive.Markdown.State do
  @moduledoc """
  Holds bounded Markdown fence state for one interactive output stream.

  The state is presentation-only and never enters journals or provider input.
  """

  @enforce_keys [:mode]
  defstruct fence_length: 3,
            language: :plain,
            line_start: true,
            mode: :prose,
            overflow: false,
            pending: ""

  @type language :: :elixir | :erlang | :plain
  @type mode :: :code | :opening | :prose
  @type t :: %__MODULE__{
          fence_length: pos_integer(),
          language: language(),
          line_start: boolean(),
          mode: mode(),
          overflow: boolean(),
          pending: String.t()
        }

  @doc "Builds fresh presentation state at the start of a prose line."
  @spec new() :: t()
  def new do
    %__MODULE__{mode: :prose}
  end
end
