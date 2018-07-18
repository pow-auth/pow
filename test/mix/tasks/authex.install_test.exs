defmodule Mix.Tasks.Authex.InstallTest do
  use Authex.Test.Mix.TestCase

  alias Mix.Tasks.Authex.Install

  @tmp_path Path.join(["tmp", inspect(Install)])
  @options  []

  setup do
    File.rm_rf!(@tmp_path)
    File.mkdir_p!(@tmp_path)

    :ok
  end

  test "generates files" do
    File.cd! @tmp_path, fn ->
      Install.run(@options ++ ~w(--context-app authex))

      path = Path.join(["lib", "authex"])
      file = "authex.ex"

      content = File.read!(Path.join(path, file))

      assert content =~ "defmodule Authex.Authex do"
      assert content =~ "user: Authex.Users.User,"
      assert content =~ "repo: Authex.Repo"

      assert File.ls!("lib/authex/users") == ["user.ex"]
    end
  end
end
