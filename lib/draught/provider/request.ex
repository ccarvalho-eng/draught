defmodule Draught.Provider.Request do
  @moduledoc """
  A provider-neutral request containing canonical messages, tools, and options.
  """

  alias Draught.Conversation.Message
  alias Draught.Provider.Options
  alias Draught.Tool.Specification
  alias Draught.Validation.Attributes
  alias Draught.Validation.Error
  alias Draught.Validation.Value

  @enforce_keys [:model, :messages, :tools, :options]
  defstruct [:model, :messages, :tools, :options]

  @type t :: %__MODULE__{
          model: String.t(),
          messages: nonempty_list(Message.t()),
          tools: [Specification.t()],
          options: Options.t()
        }

  @doc "Builds a validated canonical provider request."
  @spec new(map() | keyword()) :: Error.result(t())
  def new(attributes) do
    with {:ok, normalized} <-
           Attributes.normalize(attributes, [:model, :messages, :tools, :options]),
         {:ok, model} <- Value.required_string(normalized, :model),
         {:ok, messages} <- messages(normalized),
         {:ok, tools} <- tools(normalized),
         :ok <- unique_tool_names(tools),
         {:ok, options} <- options(normalized) do
      {:ok, %__MODULE__{model: model, messages: messages, tools: tools, options: options}}
    end
  end

  defp messages(attributes) do
    with {:ok, values} <- Attributes.fetch_required(attributes, :messages) do
      normalize_messages(values)
    end
  end

  defp normalize_messages([]) do
    Error.single([:messages], :invalid_value, "must contain at least one message")
  end

  defp normalize_messages(values) when is_list(values) do
    normalize_list(values, &normalize_message/2)
  end

  defp normalize_messages(_values) do
    Error.single([:messages], :invalid_type, "must be a list")
  end

  defp normalize_message(message, index) when is_struct(message) do
    case Message.validate(message) do
      {:ok, valid_message} -> {:ok, valid_message}
      {:error, error} -> {:error, prefix_error(error, [:messages, index])}
    end
  end

  defp normalize_message(message, index) when is_map(message) or is_list(message) do
    case Message.new(message) do
      {:ok, valid_message} -> {:ok, valid_message}
      {:error, error} -> {:error, prefix_error(error, [:messages, index])}
    end
  end

  defp normalize_message(_message, index) do
    Error.single([:messages, index], :invalid_type, "must be a canonical message")
  end

  defp tools(attributes) do
    case Map.get(attributes, :tools, []) do
      values when is_list(values) -> normalize_list(values, &normalize_tool/2)
      _values -> Error.single([:tools], :invalid_type, "must be a list")
    end
  end

  defp normalize_tool(%Specification{} = specification, _index) do
    specification
    |> Map.from_struct()
    |> Specification.new()
  end

  defp normalize_tool(specification, index)
       when is_map(specification) or is_list(specification) do
    case Specification.new(specification) do
      {:ok, tool} -> {:ok, tool}
      {:error, error} -> {:error, prefix_error(error, [:tools, index])}
    end
  end

  defp normalize_tool(_specification, index) do
    Error.single([:tools, index], :invalid_type, "must be a tool specification")
  end

  defp unique_tool_names(tools) do
    names = Enum.map(tools, & &1.name)

    names
    |> unique?()
    |> unique_tool_names_result()
  end

  defp unique?(values) do
    unique_count =
      values
      |> MapSet.new()
      |> MapSet.size()

    unique_count == length(values)
  end

  defp unique_tool_names_result(true) do
    :ok
  end

  defp unique_tool_names_result(false) do
    Error.single([:tools], :invalid_relationship, "must have unique names")
  end

  defp options(attributes) do
    case Map.get(attributes, :options, %{}) do
      %Options{} = options ->
        options
        |> Map.from_struct()
        |> Options.new()

      options ->
        Options.new(options)
    end
  end

  defp normalize_list(values, normalizer) do
    values
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {value, index}, {:ok, normalized} ->
      case normalizer.(value, index) do
        {:ok, valid_value} -> {:cont, {:ok, [valid_value | normalized]}}
        {:error, _error} = result -> {:halt, result}
      end
    end)
    |> reverse_values()
  end

  defp reverse_values({:ok, values}) do
    {:ok, Enum.reverse(values)}
  end

  defp reverse_values({:error, _error} = result) do
    result
  end

  defp prefix_error(%Error{violations: violations}, prefix) do
    prefixed =
      Enum.map(violations, fn violation ->
        %{violation | path: prefix ++ violation.path}
      end)

    Error.new(prefixed)
  end
end
