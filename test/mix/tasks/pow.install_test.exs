defmodule Mix.Tasks.Pow.InstallTest do
  use Pow.Test.Mix.TestCase

  alias Mix.Tasks.Pow.Install

  @tmp_path Path.join(["tmp", inspect(Install)])
  @options  []

  setup do
    File.rm_rf!(@tmp_path)
    File.mkdir_p!(@tmp_path)

    :ok
  end

  test "generates files" do
    File.cd! @tmp_path, fn ->
      Install.run(@options ++ ~w(--context-app pow))

      assert File.ls!("lib/pow/users") == ["user.ex"]
    end
  end
end
