defmodule Draught.CLI.Doctor.Report do
  @moduledoc """
  Complete read-only CLI diagnostic report.
  """

  alias Draught.CLI.Configuration
  alias Draught.CLI.Doctor.Check

  @enforce_keys [:checks, :configuration, :status]
  defstruct [:checks, :configuration, :status]

  @type status :: :ok | :error
  @type t :: %__MODULE__{
          checks: [Check.t()],
          configuration: map(),
          status: status()
        }

  @doc "Builds a report and derives its aggregate status."
  @spec new([Check.t()], Configuration.t()) :: t()
  def new(checks, %Configuration{} = configuration) when is_list(checks) do
    status = status(checks)

    %__MODULE__{
      checks: checks,
      configuration: Configuration.safe_projection(configuration),
      status: status
    }
  end

  defp status(checks) do
    checks
    |> Enum.all?(&(&1.status == :ok))
    |> status_result()
  end

  defp status_result(true) do
    :ok
  end

  defp status_result(false) do
    :error
  end
end
