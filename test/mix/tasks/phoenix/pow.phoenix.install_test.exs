defmodule Mix.Tasks.Pow.Phoenix.InstallTest do
  use Pow.Test.Mix.TestCase

  alias Mix.Tasks.Pow.Phoenix.Install

  @options        []
  @success_msg    "Pow has been installed in your Phoenix app!"

  test "default", context do
    File.cd!(context.tmp_path, fn ->
      Install.run(@options)

      refute File.exists?(context.paths.templates_path)
      refute File.exists?(context.paths.views_path)

      injecting_config_message = "* injecting #{context.paths.config_path}"
      injecting_endpoint_message = "* injecting #{context.paths.endpoint_path}"
      injecting_router_path_message = "* injecting #{context.paths.router_path}"

      assert_received {:mix_shell, :info, [^injecting_config_message]}
      assert_received {:mix_shell, :info, [^injecting_endpoint_message]}
      assert_received {:mix_shell, :info, [^injecting_router_path_message]}
      assert_received {:mix_shell, :info, [@success_msg]}

      expected_config =
        """
        config :pow, :pow,
          user: Pow.Users.User,
          repo: Pow.Repo

        # Import environment specific config. This must remain at the bottom
        """

      expected_endpoint =
        """
          plug Plug.Session, @session_options
          plug Pow.Plug.Session, otp_app: :pow
        """

      expected_router_head =
        """
          use PowWeb, :router
          use Pow.Phoenix.Router
        """

      expected_router_body =
        """
          scope "/" do
            pipe_through :browser

            pow_routes()
          end

          scope "/", PowWeb do
        """

      assert File.read!(context.paths.config_path) =~ expected_config
      assert File.read!(context.paths.endpoint_path) =~ expected_endpoint
      assert File.read!(context.paths.router_path) =~ expected_router_head
      assert File.read!(context.paths.router_path) =~ expected_router_body
    end)
  end

  test "when files don't exist", context do
    File.cd!(context.tmp_path, fn ->
      File.rm_rf!(context.paths.web_path)
      File.rm_rf!(context.paths.config_path)

      assert_raise Mix.Error, "Couldn't install Pow! Did you run this inside your Phoenix app?", fn ->
        Install.run(@options)
      end

      assert_received {:mix_shell, :error, ["Could not find the following file(s)" <> msg]}
      assert msg =~ context.paths.config_path
      assert msg =~ context.paths.endpoint_path
      assert msg =~ context.paths.router_path
    end)
  end

  test "when files can't be configured", context do
    File.cd!(context.tmp_path, fn ->
      File.write!(context.paths.config_path, "")
      File.write!(context.paths.endpoint_path, "")
      File.write!(context.paths.router_path, "")

      Install.run(@options)

      assert_received {:mix_shell, :error, ["Could not configure the following files:" <> msg]}
      assert msg =~ context.paths.config_path
      assert msg =~ context.paths.endpoint_path
      assert msg =~ context.paths.router_path

      assert_received {:mix_shell, :info, ["To complete please do the following:" <> msg]}
      assert msg =~ "Append this to config/config.exs:"
      assert msg =~ "config :pow, :pow,"
      assert msg =~ "user: Pow.Users.User,"
      assert msg =~ "repo: Pow.Repo"
      assert msg =~ "Add the `Pow.Plug.Session` plug to lib/pow_web/endpoint.ex after the `Plug.Session` plug:"
      assert msg =~ "plug Pow.Plug.Session, otp_app: :pow"
      assert msg =~ "Update `lib/pow_web/router.ex` with the Pow routes:"
      assert msg =~ "use Pow.Phoenix.Router"
      assert msg =~ "pow_routes()"
    end)
  end

  test "when files already configured", context do
    File.cd!(context.tmp_path, fn ->
      Install.run(@options)
      Mix.shell().flush()

      Install.run(@options)

      for path <- [context.paths.config_path, context.paths.endpoint_path, context.paths.router_path] do
        message = "* already configured #{path}"
        assert_received {:mix_shell, :info, [^message]}
      end

      assert_received {:mix_shell, :info, [@success_msg]}
    end)
  end

  test "with templates", context do
    options = @options ++ ~w(--templates)

    File.cd!(context.tmp_path, fn ->
      Install.run(options)

      assert File.exists?(context.paths.templates_path)
      assert [_one, _two] = File.ls!(context.paths.templates_path)
      assert File.exists?(context.paths.views_path)
      assert [_one, _two] = File.ls!(context.paths.views_path)
    end)
  end

  test "with extension templates", context do
    options = @options ++ ~w(--templates --extension PowResetPassword --extension PowEmailConfirmation)

    File.cd!(context.tmp_path, fn ->
      Install.run(options)

      assert File.exists?(context.paths.templates_path)
      reset_password_templates = Path.join([context.paths.web_path, "templates", "pow_reset_password"])
      assert [_one] = File.ls!(reset_password_templates)
      reset_password_views = Path.join([context.paths.web_path, "views", "pow_reset_password"])
      assert File.exists?(reset_password_views)
      assert [_one] = File.ls!(reset_password_views)
    end)
  end

  @tag web_module: "Pow", context_module: "Test"
  test "with `:context_app`", context do
    File.cd!(context.tmp_path, fn ->
      Install.run(@options ++ ~w(--context-app test --templates))

      assert_received {:mix_shell, :info, ["* injecting config/config.exs"]}
      assert_received {:mix_shell, :info, [@success_msg]}
      assert_received {:mix_shell, :info, ["Pow Phoenix templates and views has been generated."]}
      assert_received {:mix_shell, :info, ["* injecting config/config.exs"]}

      assert config_content = File.read!(context.paths.config_path)

      assert config_content =~ "user: Test.Users.User,"
      assert config_content =~ "web_module: Pow,"
    end)
  end

  @tag web_module: "Pow", context_module: "MyApp"
  describe "with `:generators` config set" do
    setup do
      Application.put_env(:pow, :generators, context_app: {:my_app, "my_app"})
      on_exit(fn ->
        Application.delete_env(:pow, :generators)
      end)
    end

    test "generates", context do
      File.cd!(context.tmp_path, fn ->
        Install.run(@options)

        assert_received {:mix_shell, :info, [@success_msg]}
        assert_received {:mix_shell, :info, ["* injecting config/config.exs"]}
        assert File.read!(context.paths.config_path) =~  "user: MyApp.Users.User,"
      end)
    end
  end

  test "raises error in app with no top level phoenix dep", context do
    File.cd!(context.tmp_path, fn ->
      File.write!("mix.exs", """
      defmodule MissingTopLevelPhoenixDep.MixProject do
        use Mix.Project

        def project do
          [
            app: :missing_top_level_phoenix_dep,
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
          Install.run(@options)
        end
      end)
    end)
  end

  @tag web_module: "POWWeb", context_module: "POW"
  describe "with `:namespace` environment config set" do
    setup do
      Application.put_env(:pow, :namespace, POW)
      on_exit(fn ->
        Application.delete_env(:pow, :namespace)
      end)
    end

    test "uses namespace for context and web module names", context do
      File.cd!(context.tmp_path, fn ->
        Install.run(~w(--templates --extension PowResetPassword))

        assert_received {:mix_shell, :info, [@success_msg]}
        assert_received {:mix_shell, :info, ["* injecting config/config.exs"]}
        assert_received {:mix_shell, :info, ["Pow Phoenix templates and views has been generated."]}
        assert_received {:mix_shell, :info, ["* injecting config/config.exs"]}

        assert config_content = File.read!(context.paths.config_path)

        assert config_content =~ "user: POW.Users.User,"
        assert config_content =~ "web_module: POWWeb,"

        view_file = Path.join([context.paths.web_path, "views", "pow", "session_view.ex"])
        assert File.exists?(view_file)
        assert File.read!(view_file) =~ "defmodule POWWeb.Pow.SessionView do"

        view_file = Path.join([context.paths.web_path, "views", "pow_reset_password", "reset_password_view.ex"])
        assert File.exists?(view_file)
        assert File.read!(view_file) =~ "defmodule POWWeb.PowResetPassword.ResetPasswordView do"
      end)
    end
  end

  @tag web_module: "MyAppWeb", context_module: "MyApp"
  test "uses web app inside Phoenix umbrella app", context do
    options = @options ++ ~w(--templates --extension PowResetPassword --extension PowEmailConfirmation)
    File.cd!(context.tmp_path, fn ->
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

        assert_received {:mix_shell, :info, [@success_msg]}
        assert_received {:mix_shell, :info, ["* injecting config/config.exs"]}
        assert_received {:mix_shell, :info, ["Pow Phoenix templates and views has been generated."]}

        assert File.read!(context.paths.config_path) =~
          """
          config :my_app_web, :pow,
            web_module: MyAppWeb,
            user: MyApp.Users.User,
            repo: MyApp.Repo
          """

        assert_received {:mix_shell, :info, ["* injecting lib/my_app_web/endpoint.ex"]}
        assert File.read!(context.paths.endpoint_path) =~ "plug Pow.Plug.Session, otp_app: :my_app_web"

        assert File.exists?(Path.join([context.paths.web_path, "templates", "pow"]))
        assert File.exists?(Path.join([context.paths.web_path, "views", "pow"]))

        assert File.exists?(Path.join([context.paths.web_path, "templates", "pow_reset_password"]))
        assert File.exists?(Path.join([context.paths.web_path, "views", "pow_reset_password"]))
      end)
    end)
  end
end
