defmodule Mix.Tasks.Pow.Phoenix.InstallTest do
  use Pow.Test.Mix.TestCase

  alias Mix.Tasks.Pow.Phoenix.Install

  @tmp_path       Path.join(["tmp", inspect(Install)])
  @options        []
  @web_path       Path.join(["lib", "pow_web"])
  @templates_path Path.join([@web_path, "templates", "pow"])
  @views_path     Path.join([@web_path, "views", "pow"])
  @expected_msg   "Pow has been installed in your phoenix app!"

  setup do
    File.rm_rf!(@tmp_path)
    File.mkdir_p!(@tmp_path)

    :ok
  end

  test "default" do
    File.cd!(@tmp_path, fn ->
      Install.run(@options)

      refute File.exists?(@templates_path)
      refute File.exists?(@views_path)

      assert_received {:mix_shell, :info, [@expected_msg <> msg]}
      assert msg =~ "config :pow, :pow,"
      assert msg =~ "user: Pow.Users.User,"
      assert msg =~ "plug Pow.Plug.Session, otp_app: :pow"
      assert msg =~ "use Pow.Phoenix.Router"
      assert msg =~ "pow_routes()"
    end)
  end

  test "with templates" do
    options = @options ++ ~w(--templates)

    File.cd!(@tmp_path, fn ->
      Install.run(options)

      assert File.exists?(@templates_path)
      assert [_one, _two] = File.ls!(@templates_path)
      assert File.exists?(@views_path)
      assert [_one, _two] = File.ls!(@views_path)
    end)
  end

  test "with extension templates" do
    options = @options ++ ~w(--templates --extension PowResetPassword --extension PowEmailConfirmation)

    File.cd!(@tmp_path, fn ->
      Install.run(options)

      assert File.exists?(@templates_path)
      reset_password_templates = Path.join(["lib", "pow_web", "templates", "pow_reset_password"])
      assert [_one] = File.ls!(reset_password_templates)
      reset_password_views = Path.join(["lib", "pow_web", "views", "pow_reset_password"])
      assert File.exists?(reset_password_views)
      assert [_one] = File.ls!(reset_password_views)
    end)
  end

  test "with `:context_app`" do
    File.cd!(@tmp_path, fn ->
      Install.run(@options ++ ~w(--context-app test --templates))

      assert_received {:mix_shell, :info, [@expected_msg <> msg]}
      assert msg =~ "user: Test.Users.User,"

      assert_received {:mix_shell, :info, ["Pow Phoenix templates and views has been generated." <> msg]}
      assert msg =~ "user: Test.Users.User"
    end)
  end

  test "raises error in app with no top level phoenix dep" do
    File.cd!(@tmp_path, fn ->
      File.write!("mix.exs", """
      defmodule MissingTopLevelPhoenixDep.MixProject do
        use Mix.Project

        def project do
          [
            deps: [
              {:phoenix_dep, path: "dep/"}
            ]
          ]
        end
      end
      """)
      File.mkdir!("dep")
      File.write!("dep/mix.exs", """
      defmodule PhoenixDep.MixProject do
        use Mix.Project

        def project do
          [
            app: :phoenix_dep,
            deps: [
              {:phoenix, ">= 0.0.0"}
            ]
          ]
        end
      end
      """)

      Mix.Project.in_project(:missing_top_level_phoenix_dep, ".", fn _ ->
        # Insurance that we do test for top level phoenix inclusion
        assert Enum.any?(Mix.Dep.load_on_environment([]), fn
          %{app: :phoenix} -> true
          _ -> false
        end), "Phoenix not loaded by dependency"

        assert_raise Mix.Error, "mix pow.phoenix.install can only be run inside an application directory that has :phoenix as dependency", fn ->
          Install.run([])
        end
      end)
    end)
  end

  describe "with `:user` and `:repo` environment config set" do
    setup do
      Application.put_env(:pow, :pow, user: Pow.Users.User, repo: Pow.Repo)
      on_exit(fn ->
        Application.delete_env(:pow, :pow)
      end)
    end

    test "doesn't print instructions" do
      File.cd!(@tmp_path, fn ->
        Install.run([])

        refute_received {:mix_shell, :info, [@expected_msg <> _msg]}
      end)
    end
  end

  describe "with `:namespace` environment config set" do
    setup do
      Application.put_env(:pow, :namespace, POW)
      on_exit(fn ->
        Application.delete_env(:pow, :namespace)
      end)
    end

    test "uses namespace for context and web module names" do
      File.cd!(@tmp_path, fn ->
        Install.run(~w(--templates --extension PowResetPassword))

        assert_received {:mix_shell, :info, [@expected_msg <> msg]}
        assert msg =~ "user: POW.Users.User,"
        assert msg =~ "defmodule POWWeb.Endpoint do"

        assert_received {:mix_shell, :info, ["Pow Phoenix templates and views has been generated." <> msg]}
        assert msg =~ "user: POW.Users.User"
        assert msg =~ "web_module: POWWeb"

        view_file = Path.join(["lib", "pow_web", "views", "pow", "session_view.ex"])
        assert File.exists?(view_file)
        assert File.read!(view_file) =~ "defmodule POWWeb.Pow.SessionView do"

        view_file = Path.join(["lib", "pow_web", "views", "pow_reset_password", "reset_password_view.ex"])
        assert File.exists?(view_file)
        assert File.read!(view_file) =~ "defmodule POWWeb.PowResetPassword.ResetPasswordView do"
      end)
    end
  end

  test "uses web app inside Phoenix umbrella app" do
    options = @options ++ ~w(--templates --extension PowResetPassword --extension PowEmailConfirmation)
    File.cd!(@tmp_path, fn ->
      File.write!("mix.exs", """
      defmodule MyAppWeb.MixProject do
        use Mix.Project

        def project do
          [
            app: :my_app_web,
            deps: [
              {:phoenix, ">= 0.0.0"}
            ]
          ]
        end
      end
      """)

      Application.put_env(:my_app_web, :generators, context_app: :my_app)

      Mix.Project.in_project(:my_app_web, ".", fn _ ->
        Install.run(options)

        assert_received {:mix_shell, :info, [@expected_msg <> msg]}
        assert msg =~ "config :my_app_web, :pow,"
        assert msg =~ "user: MyApp.Users.User,"
        assert msg =~ "plug Pow.Plug.Session, otp_app: :my_app_web"

        assert_received {:mix_shell, :info, ["Pow Phoenix templates and views has been generated." <> msg]}
        assert msg =~ "repo: MyApp.Repo"
        assert msg =~ "user: MyApp.Users.User"
        assert msg =~ "web_module: MyAppWeb"

        assert File.exists?(Path.join(["lib", "my_app_web", "templates", "pow"]))
        assert File.exists?(Path.join(["lib", "my_app_web", "views", "pow"]))

        assert File.exists?(Path.join(["lib", "my_app_web", "templates", "pow_reset_password"]))
        assert File.exists?(Path.join(["lib", "my_app_web", "views", "pow_reset_password"]))
      end)
    end)
  end
end
