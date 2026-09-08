defmodule Draught.CLI.Configuration.User.PreferenceTest do
  use ExUnit.Case, async: true

  alias Draught.CLI.Configuration.User.Preference
  alias Draught.CLI.System.Local

  defmodule SystemAdapter do
    @moduledoc false

    @spec environment(map()) :: map()
    def environment(configuration) do
      configuration.environment
    end

    @spec read_file(String.t(), pos_integer(), term()) ::
            Draught.CLI.System.Adapter.file_result()
    def read_file(path, maximum_bytes, _configuration) do
      Local.read_file(path, maximum_bytes, nil)
    end

    @spec write_file(String.t(), binary(), term()) ::
            :ok | {:error, :io | :publication_unknown | :unsafe_file}
    def write_file(path, content, _configuration) do
      Local.write_file(path, content, nil)
    end
  end

  @tag :tmp_dir
  test "creates the user configuration with the selected model", %{tmp_dir: directory} do
    system = system(%{"XDG_CONFIG_HOME" => directory})

    assert Preference.save_model("qwen3", system) == :ok

    path = Path.join([directory, "draught", "config.json"])
    content = File.read!(path)
    assert {:ok, %{"model" => "qwen3"}} = Jason.decode(content)
  end

  @tag :tmp_dir
  test "preserves validated user settings while changing only the model", %{tmp_dir: directory} do
    path = Path.join([directory, ".config", "draught", "config.json"])

    path
    |> Path.dirname()
    |> File.mkdir_p!()

    existing = %{
      "model" => "old-model",
      "profile" => "lab",
      "profiles" => %{
        "lab" => %{
          "base_url" => "http://localhost:11434",
          "provider" => "ollama"
        }
      },
      "risk" => "deny"
    }

    File.write!(path, Jason.encode!(existing))
    system = system(%{"HOME" => directory})

    assert Preference.save_model("new-model", system) == :ok
    content = File.read!(path)
    assert {:ok, updated} = Jason.decode(content)
    assert updated == Map.put(existing, "model", "new-model")
  end

  test "fails closed when no user configuration root is available" do
    assert Preference.save_model("qwen3", system(%{})) == {:error, :not_saved}
  end

  @tag :tmp_dir
  test "does not replace an unsafe user configuration file", %{tmp_dir: directory} do
    draught = Path.join(directory, "draught")
    path = Path.join(draught, "config.json")
    target = Path.join(directory, "target.json")
    File.mkdir_p!(draught)
    File.write!(target, ~s({"model":"unchanged"}))
    File.ln_s!(target, path)

    assert Preference.save_model("qwen3", system(%{"XDG_CONFIG_HOME" => directory})) ==
             {:error, :not_saved}

    content = File.read!(target)
    assert {:ok, %{"model" => "unchanged"}} = Jason.decode(content)
  end

  defp system(environment) do
    {SystemAdapter, %{environment: environment}}
  end
end
