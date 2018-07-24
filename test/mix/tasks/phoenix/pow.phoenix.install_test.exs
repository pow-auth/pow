defmodule Mix.Tasks.Pow.Phoenix.InstallTest do
  use Pow.Test.Mix.TestCase

  alias Mix.Tasks.Pow.Phoenix.Install

  defmodule Repo do
    def __adapter__, do: true
    def config, do: [priv: "", otp_app: :pow]
  end

  @tmp_path Path.join(["tmp", inspect(Install)])
  @options  ["-r", inspect(Repo)]
  @web_path Path.join(["lib", "pow_web"])
  @templates_path Path.join([@web_path, "templates", "pow"])
  @views_path Path.join([@web_path, "views", "pow"])

  setup do
    File.rm_rf!(@tmp_path)
    File.mkdir_p!(@tmp_path)

    :ok
  end

  test "default" do
    File.cd! @tmp_path, fn ->
      Install.run(@options)

      content = File.read!("lib/pow_web/pow.ex")

      assert content =~ "defmodule PowWeb.Pow do"
      assert content =~ "use Pow.Phoenix,"
      assert content =~ "user: Pow.Users.User,"
      assert content =~ "repo: Pow.Repo,"
      assert content =~ "extensions: []"

      refute File.exists?(@templates_path)
      refute File.exists?(@views_path)

      assert_received {:mix_shell, :info, [_msg]}
      assert_received {:mix_shell, :info, [msg]}
      assert msg =~ "plug PowWeb.Pow.Plug.Session"
      assert msg =~ "repo: Pow.Repo"
      assert msg =~ "user: Pow.Users.User"

      assert msg =~ "use PowWeb.Pow.Phoenix.Router"
      assert msg =~ "pow_routes()"
    end
  end

  test "with templates" do
    File.cd! @tmp_path, fn ->
      Install.run(@options ++ ~w(--templates))

      assert File.exists?(@templates_path)
      assert [_one, _two] = File.ls!(@templates_path)
      assert File.exists?(@views_path)
      assert [_one, _two] = File.ls!(@views_path)
    end
  end

  test "with extension templates" do
    File.cd! @tmp_path, fn ->
      Install.run(@options ++ ~w(--templates --extension PowResetPassword --extension PowEmailConfirmation))

      content = File.read!("lib/pow_web/pow.ex")
      assert content =~ "extensions: [PowResetPassword, PowEmailConfirmation]"

      assert File.exists?(@templates_path)
      reset_password_templates = Path.join(["lib", "pow_web", "templates", "pow_reset_password"])
      assert [_one] = File.ls!(reset_password_templates)
      reset_password_views = Path.join(["lib", "pow_web", "views", "pow_reset_password"])
      assert File.exists?(reset_password_views)
      assert [_one] = File.ls!(reset_password_views)
    end
  end
end
