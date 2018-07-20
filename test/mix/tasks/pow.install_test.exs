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

      path = Path.join(["lib", "pow"])
      file = "pow.ex"

      content = File.read!(Path.join(path, file))

      assert content =~ "defmodule Pow.Pow do"
      assert content =~ "user: Pow.Users.User,"
      assert content =~ "repo: Pow.Repo"

      assert File.ls!("lib/pow/users") == ["user.ex"]
    end
  end

  test "handles extensions" do
    File.cd! @tmp_path, fn ->
      Install.run(@options ++ ~w(--extension PowResetPassword --extension PowEmailConfirmation))

      path = Path.join(["lib", "pow"])
      file = "pow.ex"

      content = File.read!(Path.join(path, file))

      assert content =~ "extensions: [PowResetPassword, PowEmailConfirmation]"
    end
  end
end
