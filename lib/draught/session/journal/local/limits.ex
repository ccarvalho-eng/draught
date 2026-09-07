defmodule Draught.Session.Journal.Local.Limits do
  @moduledoc false

  @journal_bytes 67_108_864
  @record_bytes 4_194_304

  @doc "Returns the maximum durable journal size."
  @spec journal_bytes() :: pos_integer()
  def journal_bytes do
    @journal_bytes
  end

  @doc "Returns the maximum encoded record size."
  @spec record_bytes() :: pos_integer()
  def record_bytes do
    @record_bytes
  end
end
