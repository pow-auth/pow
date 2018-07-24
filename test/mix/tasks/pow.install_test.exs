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

      content = File.read!("lib/pow/pow.ex")

      assert content =~ "defmodule Pow.Pow do"
      assert content =~ "use Pow,"
      assert content =~ "extensions: []"

      assert File.ls!("lib/pow/users") == ["user.ex"]

      content = File.read!("lib/pow_web/pow.ex")

      assert content =~ "defmodule PowWeb.Pow do"
      assert content =~ "use Pow.Phoenix,"
      assert content =~ "user: Pow.Users.User,"
      assert content =~ "repo: Pow.Repo,"
      assert content =~ "extensions: []"
    end
  end

  test "handles extensions" do
    File.cd! @tmp_path, fn ->
      Install.run(@options ++ ~w(--extension PowResetPassword --extension PowEmailConfirmation))

      content = File.read!("lib/pow/pow.ex")
      assert content =~ "extensions: [PowResetPassword, PowEmailConfirmation]"

      content = File.read!("lib/pow_web/pow.ex")
      assert content =~ "extensions: [PowResetPassword, PowEmailConfirmation]"
    end
  end
end
