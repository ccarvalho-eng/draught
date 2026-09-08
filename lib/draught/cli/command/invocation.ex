defmodule Draught.CLI.Command.Invocation do
  @moduledoc """
  Immutable terminal-independent intent produced by command parsing.
  """

  @enforce_keys [:command]
  defstruct command: nil,
            prompt: nil,
            provider: nil,
            model: nil,
            base_url: nil,
            session: nil,
            resume: nil,
            web: :inherit,
            web_search: :inherit,
            web_search_url: nil,
            output: :text,
            color: :auto,
            diagnostics: false

  @type command :: :task | :interactive | :doctor | :help | :version
  @type web :: :inherit | :enabled | :disabled
  @type output :: :text | :jsonl
  @type color :: :auto | :always | :never

  @type t :: %__MODULE__{
          command: command(),
          prompt: String.t() | nil,
          provider: String.t() | nil,
          model: String.t() | nil,
          base_url: String.t() | nil,
          session: String.t() | nil,
          resume: String.t() | nil,
          web: web(),
          web_search: web(),
          web_search_url: String.t() | nil,
          output: output(),
          color: color(),
          diagnostics: boolean()
        }
end
