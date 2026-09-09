defmodule Draught.CLI.Interactive.Terminal.Editor.Driver.Local do
  @moduledoc """
  Adapts OTP's native no-shell terminal mode to the prompt editor.

  Raw mode is entered only for one idle prompt and restored to cooked mode
  before approvals or other line-oriented reads can begin.
  """

  @behaviour Draught.CLI.Interactive.Terminal.Editor.Driver

  @fallback_columns 80

  @impl Draught.CLI.Interactive.Terminal.Editor.Driver
  def enter_raw(_configuration) do
    case :shell.start_interactive({:noshell, :raw}) do
      :ok -> :ok
      {:error, _reason} -> {:error, :unsupported}
    end
  catch
    :exit, _reason -> {:error, :unsupported}
  end

  @impl Draught.CLI.Interactive.Terminal.Editor.Driver
  def restore(_configuration) do
    _result = :shell.start_interactive({:noshell, :cooked})
    :ok
  catch
    :exit, _reason -> :ok
  end

  @impl Draught.CLI.Interactive.Terminal.Editor.Driver
  def read(_configuration) do
    ""
    |> :io.get_chars(1)
    |> read_result()
  catch
    :exit, _reason -> {:error, :io}
  end

  @impl Draught.CLI.Interactive.Terminal.Editor.Driver
  def write(content, _configuration) do
    IO.write(content)
    :ok
  rescue
    ErlangError -> {:error, :io}
  catch
    :exit, _reason -> {:error, :io}
  end

  @impl Draught.CLI.Interactive.Terminal.Editor.Driver
  def columns(_configuration) do
    case :io.columns() do
      {:ok, columns} when is_integer(columns) and columns > 0 -> columns
      _unavailable -> @fallback_columns
    end
  catch
    :exit, _reason -> @fallback_columns
  end

  defp read_result(:eof) do
    :eof
  end

  defp read_result({:error, _reason}) do
    {:error, :io}
  end

  defp read_result(value) when is_binary(value) do
    {:ok, value}
  end

  defp read_result(value) when is_list(value) do
    value
    |> :unicode.characters_to_binary()
    |> unicode_result()
  rescue
    ArgumentError -> {:error, :io}
  end

  defp unicode_result(value) when is_binary(value) do
    {:ok, value}
  end

  defp unicode_result(_value) do
    {:error, :io}
  end
end
