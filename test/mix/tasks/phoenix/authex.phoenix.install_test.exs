defmodule Mix.Tasks.Authex.Phoenix.InstallTest do
  use Authex.Test.Mix.TestCase

  alias Mix.Tasks.Authex.Phoenix.Install

  defmodule Repo do
    def __adapter__, do: true
    def config, do: [priv: "", otp_app: :authex]
  end

  @tmp_path Path.join(["tmp", inspect(Install)])
  @options  ["-r", inspect(Repo)]
  @context_path Path.join(["lib", "authex", "users"])
  @templates_path Path.join(["lib", "authex_web", "templates", "authex"])
  @views_path Path.join(["lib", "authex_web", "views", "authex"])

  setup do
    File.rm_rf!(@tmp_path)
    File.mkdir_p!(@tmp_path)

    :ok
  end

  test "default" do
    File.cd! @tmp_path, fn ->
      Install.run(@options)

      assert File.ls!(@context_path) == ["user.ex"]
      assert [_one] = File.ls!("migrations")
      refute File.exists?(@templates_path)
      refute File.exists?(@views_path)


      for _ <- 1..4, do: assert_received {:mix_shell, :info, [_msg]}
      assert_received {:mix_shell, :info, [msg]}
      assert msg =~ "plug Authex.Plug.Session"
      assert msg =~ "repo: Authex.Repo"
      assert msg =~ "user: Authex.Users.User"

      assert msg =~ "use Authex.Phoenix.Router"
      assert msg =~ "authex_routes()"
    end
  end

  test "with templates" do
    File.cd! @tmp_path, fn ->
      Install.run(@options ++ ~w(--templates))

      assert File.ls!(@context_path) == ["user.ex"]
      assert [_one] = File.ls!("migrations")
      assert File.exists?(@templates_path)
      assert [_one, _two] = File.ls!(@templates_path)
      assert File.exists?(@views_path)
      assert [_one, _two] = File.ls!(@views_path)
    end
  end
end
