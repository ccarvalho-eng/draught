defmodule Draught.CLI.UI.Theme do
  @moduledoc """
  Defines the semantic terminal palette used by Draught's Owl presentation.

  Roles describe meaning rather than individual screens so color choices stay
  consistent and plain output remains available from the same call sites.
  """

  alias Elixir.Owl.Data

  @styles %{
    accent: [:magenta, :bright],
    command: [:yellow, :bright],
    error: :red,
    model: [:magenta, :bright],
    muted: :light_black,
    path: :cyan,
    success: :green
  }

  @type role :: :accent | :command | :error | :model | :muted | :path | :success

  @doc "Tags presentation data with a semantic role when styling is enabled."
  @spec tag(Data.t(), role(), boolean()) :: Data.t()
  def tag(content, role, true) do
    Data.tag(content, style(role, true))
  end

  def tag(content, _role, false) do
    content
  end

  @doc "Renders semantic presentation data as terminal chardata."
  @spec chardata(Data.t(), role(), boolean()) :: IO.chardata()
  def chardata(content, role, true) do
    IO.ANSI.format([style(role, true), content, :reset], true)
  end

  def chardata(content, _role, false) do
    content
  end

  @doc "Returns the Owl style sequence for a semantic role."
  @spec style(role(), boolean()) :: Data.sequence() | [Data.sequence()]
  def style(role, true) do
    Map.fetch!(@styles, role)
  end

  def style(_role, false) do
    []
  end
end
