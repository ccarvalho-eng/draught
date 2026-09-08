defmodule Draught.CLI.Command.Options do
  @moduledoc """
  Validates option occurrences and projects them into the immutable command invocation.
  """

  alias Draught.CLI.Command.Error
  alias Draught.CLI.Command.Specification

  @display_controls ~r/[\x00-\x1F\x7F\x{0080}-\x{009F}\x{061C}\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/u

  @enforce_keys [:present]
  defstruct provider: nil,
            model: nil,
            base_url: nil,
            session: nil,
            resume: nil,
            web: :inherit,
            web_search: :inherit,
            web_search_url: nil,
            output: :text,
            color: :auto,
            diagnostics: false,
            help: false,
            version: false,
            present: MapSet.new()

  @type t :: %__MODULE__{
          provider: String.t() | nil,
          model: String.t() | nil,
          base_url: String.t() | nil,
          session: String.t() | nil,
          resume: String.t() | nil,
          web: :inherit | :enabled | :disabled,
          web_search: :inherit | :enabled | :disabled,
          web_search_url: String.t() | nil,
          output: :text | :jsonl,
          color: :auto | :always | :never,
          diagnostics: boolean(),
          help: boolean(),
          version: boolean(),
          present: MapSet.t(atom())
        }

  @doc "Parses and normalizes the closed option specification."
  @spec parse([String.t()]) :: {:ok, t(), [String.t()]} | {:error, Error.t()}
  def parse(arguments) do
    with :ok <- metadata_negation(arguments) do
      arguments
      |> OptionParser.parse(strict: Specification.switches(), aliases: Specification.aliases())
      |> parse_result()
    end
  end

  @doc "Returns whether an option was explicitly present."
  @spec present?(t(), atom()) :: boolean()
  def present?(%__MODULE__{present: present}, key) do
    MapSet.member?(present, key)
  end

  defp metadata_negation(arguments) do
    invalid = Enum.any?(arguments, &(&1 in ["--no-help", "--no-version"]))
    valid_result(not invalid, :invalid_option, "Help and version cannot be negated")
  end

  defp parse_result({options, positionals, []}) do
    with :ok <- duplicates(options),
         {:ok, normalized} <- normalize(options),
         :ok <- conflicts(normalized) do
      {:ok, normalized, positionals}
    end
  end

  defp parse_result({_options, _positionals, [{switch, nil} | _invalid]}) do
    invalid_switch(switch)
  end

  defp parse_result({_options, _positionals, _invalid}) do
    error(:invalid_option, "A command option has an invalid value")
  end

  defp invalid_switch(switch) do
    switch
    |> known_switch?()
    |> invalid_switch_result()
  end

  defp known_switch?("-h") do
    true
  end

  defp known_switch?("-v") do
    true
  end

  defp known_switch?(switch) do
    Enum.any?(Specification.options(), &matches_switch?(&1, switch))
  end

  defp matches_switch?(%{switch: "--[no-]" <> name}, switch) do
    switch in ["--" <> name, "--no-" <> name]
  end

  defp matches_switch?(option, switch) do
    option.switch == switch
  end

  defp invalid_switch_result(true) do
    error(:invalid_option, "A command option is missing or has an invalid value")
  end

  defp invalid_switch_result(false) do
    error(:unknown_option, "Unknown command option")
  end

  defp duplicates(options) do
    keys = Keyword.keys(options)

    unique_count =
      keys
      |> MapSet.new()
      |> MapSet.size()

    valid = unique_count == Enum.count(keys)
    valid_result(valid, :duplicate_option, "Command options must not repeat")
  end

  defp normalize(options) do
    values = Map.new(options)

    with {:ok, strings} <- string_values(values),
         {:ok, output} <- output(values),
         {:ok, color} <- color(values) do
      {:ok, build(values, strings, output, color)}
    end
  end

  defp string_values(values) do
    with {:ok, provider} <- optional_value(values, :provider),
         {:ok, model} <- optional_value(values, :model),
         {:ok, base_url} <- optional_value(values, :base_url),
         {:ok, web_search_url} <- optional_value(values, :web_search_url),
         {:ok, session} <- optional_value(values, :session),
         {:ok, resume} <- optional_value(values, :resume) do
      {:ok, {provider, model, base_url, web_search_url, session, resume}}
    end
  end

  defp build(values, strings, output, color) do
    {provider, model, base_url, web_search_url, session, resume} = strings

    %__MODULE__{
      provider: provider,
      model: model,
      base_url: base_url,
      session: session,
      resume: resume,
      web: boolean_setting(values, :web),
      web_search: boolean_setting(values, :web_search),
      web_search_url: web_search_url,
      output: output,
      color: color,
      diagnostics: Map.get(values, :diagnostics, false),
      help: Map.get(values, :help, false),
      version: Map.get(values, :version, false),
      present:
        values
        |> Map.keys()
        |> MapSet.new()
    }
  end

  defp optional_value(values, key) do
    case Map.fetch(values, key) do
      {:ok, value} -> validate_option_value(value, key)
      :error -> {:ok, nil}
    end
  end

  defp validate_option_value(value, _key) when not is_binary(value) do
    error(:invalid_option_value, "A command option has an invalid value")
  end

  defp validate_option_value("", _key) do
    error(:invalid_option_value, "Command option values must not be empty")
  end

  defp validate_option_value(value, key) do
    maximum = Specification.limits().option_value_bytes
    valid = byte_size(value) <= maximum and not Regex.match?(@display_controls, value)
    option_value_result(valid, value, key)
  end

  defp option_value_result(true, value, _key) do
    {:ok, value}
  end

  defp option_value_result(false, _value, key) do
    error(:invalid_option_value, "The #{option_name(key)} option has an invalid value")
  end

  defp option_name(key) do
    key
    |> Atom.to_string()
    |> String.replace("_", "-")
  end

  defp output(%{output: "text"}) do
    {:ok, :text}
  end

  defp output(%{output: "jsonl"}) do
    {:ok, :jsonl}
  end

  defp output(%{output: _value}) do
    error(:invalid_option_value, "Output must be text or jsonl")
  end

  defp output(_values) do
    {:ok, :text}
  end

  defp color(%{color: "auto"}) do
    {:ok, :auto}
  end

  defp color(%{color: "always"}) do
    {:ok, :always}
  end

  defp color(%{color: "never"}) do
    {:ok, :never}
  end

  defp color(%{color: _value}) do
    error(:invalid_option_value, "Color must be auto, always, or never")
  end

  defp color(_values) do
    {:ok, :auto}
  end

  defp boolean_setting(values, key) do
    case Map.fetch(values, key) do
      {:ok, true} -> :enabled
      {:ok, false} -> :disabled
      :error -> :inherit
    end
  end

  defp conflicts(%__MODULE__{help: true, version: true}) do
    error(:conflicting_options, "Help and version options cannot be combined")
  end

  defp conflicts(%__MODULE__{session: session, resume: resume}) do
    conflict = not is_nil(session) and not is_nil(resume)

    valid_result(
      not conflict,
      :conflicting_options,
      "Session and resume options cannot be combined"
    )
  end

  defp valid_result(true, _code, _message) do
    :ok
  end

  defp valid_result(false, code, message) do
    error(code, message)
  end

  defp error(code, message) do
    {:error, Error.new(code, message)}
  end
end
