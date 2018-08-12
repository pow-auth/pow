defmodule Mix.Tasks.Pow.InstallTest do
  use Pow.Test.Mix.TestCase

  alias Mix.Tasks.Pow.Install

  @tmp_path Path.join(["tmp", inspect(Install)])

  setup do
    File.rm_rf!(@tmp_path)
    File.mkdir_p!(@tmp_path)

    :ok
  end

  test "generates files" do
    options = ~w(--context-app pow)

    File.cd!(@tmp_path, fn ->
      Install.run(options)

      assert File.ls!("lib/pow/users") == ["user.ex"]
    end)
  end
end
