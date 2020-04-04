defmodule Pow.MixTest do
  use ExUnit.Case

  alias Pow.MixProject

  test "elixirc_paths/1" do
    assert MixProject.elixirc_paths(:test, []) == ["lib", "test/support"]
    assert MixProject.elixirc_paths(:test, [phoenix: false]) == ["lib", "test/support"]

    assert MixProject.elixirc_paths(:dev, []) == ["lib"]

    assert paths = MixProject.elixirc_paths(:dev, [phoenix: false])
    refute some_paths?(paths, "/phoenix")
    assert some_paths?(paths, "/ecto")
    assert some_paths?(paths, "/plug")

    assert paths = MixProject.elixirc_paths(:dev, [ecto: false, plug: false])
    assert some_paths?(paths, "/phoenix")
    refute some_paths?(paths, "/ecto")
    refute some_paths?(paths, "/plug")
  end

  test "compilers/1" do
    compilers = [:yecc, :leex, :erlang, :elixir, :xref, :app]

    assert MixProject.compilers([]) == compilers
    assert MixProject.compilers([{:phoenix, false}]) == compilers
    assert MixProject.compilers([{:phoenix, true}]) == [:phoenix] ++ compilers
  end

  defp some_paths?(paths, path) do
    Enum.any?(paths, &(String.contains?(&1, path)))
  end
end
