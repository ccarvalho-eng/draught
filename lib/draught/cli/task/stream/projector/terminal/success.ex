defmodule Draught.CLI.Task.Stream.Projector.Terminal.Success do
  @moduledoc """
  Projects one successful terminal response against visible streamed text.
  """

  alias Draught.CLI.Output.Sanitizer
  alias Draught.CLI.Task.Stream.Event
  alias Draught.CLI.Task.Stream.Projector.State
  alias Draught.Conversation.Content.Text
  alias Draught.Provider.Response

  @maximum_content_bytes 8_192

  @doc "Builds one bounded success event or rejects inconsistent streamed content."
  @spec project(State.t(), Response.t()) ::
          {:emit, State.t(), Event.t()} | {:error, :inconsistent_stream}
  def project(%State{} = state, %Response{} = response) do
    with {:ok, streamed, content, trailing_newline} <- terminal_content(state, response) do
      event =
        Event.new(:success, state.sequence,
          content: content,
          finish_reason: response.finish_reason,
          prefix_newline: trailing_newline,
          streamed: streamed,
          usage: usage(response)
        )

      {:emit, State.terminal(state), event}
    end
  end

  defp terminal_content(state, response) do
    content = visible_content(response)
    streamed = State.streamed_final_iteration?(state)
    trailing_newline = streamed and not String.ends_with?(content, "\n")
    terminal_content(streamed, state.current_text, content, trailing_newline)
  end

  defp terminal_content(false, _streamed_content, content, _trailing_newline) do
    {:ok, false, Sanitizer.text(content, @maximum_content_bytes), false}
  end

  defp terminal_content(true, streamed_content, content, trailing_newline) do
    matches = String.starts_with?(content, streamed_content)
    consistency_result(matches, streamed_content, content, trailing_newline)
  end

  defp consistency_result(true, streamed_content, content, trailing_newline) do
    {:ok, true, missing_content(content, streamed_content), trailing_newline}
  end

  defp consistency_result(false, _streamed_content, _content, _trailing_newline) do
    {:error, :inconsistent_stream}
  end

  defp missing_content(content, streamed_content) do
    content
    |> binary_part(byte_size(streamed_content), byte_size(content) - byte_size(streamed_content))
    |> Sanitizer.text(@maximum_content_bytes)
    |> empty_content()
  end

  defp empty_content("") do
    nil
  end

  defp empty_content(content) do
    content
  end

  defp visible_content(response) do
    response.message.content
    |> Enum.flat_map(fn
      %Text{text: text} -> [text]
      _content -> []
    end)
    |> IO.iodata_to_binary()
    |> Sanitizer.text()
  end

  defp usage(%Response{usage: nil}) do
    nil
  end

  defp usage(%Response{usage: usage}) do
    values = Map.from_struct(usage)

    if Enum.all?(values, fn {_key, value} -> value <= 9_223_372_036_854_775_807 end) do
      Map.new(values, fn {key, value} -> {Atom.to_string(key), value} end)
    end
  end
end
