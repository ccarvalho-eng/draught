defmodule Draught.CLI.Interactive.Completion do
  @moduledoc """
  Expands interactive command and model prefixes without performing effects.

  Erlang's terminal editor supplies the input before the cursor in reverse
  order. Results use its documented expansion tuple and contain only validated
  catalog values.
  """

  alias Draught.CLI.Interactive.Completion.Context

  @no_completion {:no, [], []}

  @doc "Expands the reversed input prefix for Erlang's terminal editor."
  @spec expand(term(), Context.t()) ::
          {:yes | :no, charlist(), [charlist()]}
  def expand(reversed, %Context{} = context) when is_list(reversed) do
    reversed
    |> Enum.reverse()
    |> :unicode.characters_to_binary()
    |> expansion_result(context)
  rescue
    ArgumentError -> @no_completion
  end

  def expand(_reversed, %Context{}) do
    @no_completion
  end

  @doc "Returns a callback compatible with the terminal expand_fun option."
  @spec function(Context.t()) :: (charlist() -> {:yes | :no, charlist(), [charlist()]})
  def function(%Context{} = context) do
    fn reversed -> expand(reversed, context) end
  end

  @doc "Rejects completion for terminal reads that are not the main prompt."
  @spec none(term()) :: {:no, [], []}
  def none(_reversed) do
    @no_completion
  end

  defp expansion("/model " <> prefix, context) do
    complete(prefix, context.models)
  end

  defp expansion("/skill " <> prefix, context) do
    complete(prefix, context.skills)
  end

  defp expansion("/" <> _command = prefix, context) do
    command(prefix, context.commands)
  end

  defp expansion(_line, _context) do
    @no_completion
  end

  defp expansion_result(value, context) when is_binary(value) do
    expansion(value, context)
  end

  defp expansion_result(_invalid, _context) do
    @no_completion
  end

  defp command(prefix, commands) do
    contains_space = Regex.match?(~r/\s/u, prefix)
    command_result(contains_space, prefix, commands)
  end

  defp command_result(true, _prefix, _commands) do
    @no_completion
  end

  defp command_result(false, prefix, commands) do
    complete(prefix, commands)
  end

  defp complete(prefix, candidates) do
    matches = Enum.filter(candidates, &String.starts_with?(&1, prefix))
    completion_result(prefix, matches)
  end

  defp completion_result(_prefix, []) do
    @no_completion
  end

  defp completion_result(prefix, [match]) do
    {:yes, suffix(match, prefix), []}
  end

  defp completion_result(prefix, matches) do
    common = longest_common_prefix(matches)
    {:yes, suffix(common, prefix), Enum.map(matches, &String.to_charlist/1)}
  end

  defp longest_common_prefix([first | rest]) do
    Enum.reduce(rest, first, &common_prefix/2)
  end

  defp common_prefix(left, right) do
    left
    |> String.graphemes()
    |> Enum.zip(String.graphemes(right))
    |> Enum.take_while(fn {left_grapheme, right_grapheme} -> left_grapheme == right_grapheme end)
    |> Enum.map_join(&elem(&1, 0))
  end

  defp suffix(value, prefix) do
    value
    |> String.replace_prefix(prefix, "")
    |> String.to_charlist()
  end
end
