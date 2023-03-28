defmodule Mix.Tasks.Pow.Extension.Phoenix.Mailer.Gen.TemplatesTest do
  use Pow.Test.Mix.TestCase

  alias Mix.Tasks.Pow.Extension.Phoenix.Mailer.Gen.Templates

  @success_msg "Pow mailer templates has been installed in your phoenix app!"
  @expected_templates [
    {PowResetPassword, ~w(reset_password)},
    {PowEmailConfirmation, ~w(email_confirmation)},
    {PowInvitation, ~w(invitation)},
  ]
  @options Enum.flat_map(@expected_templates, &["--extension", inspect(elem(&1, 0))])

  setup context do
    web_file = context.paths.web_path <> ".ex"

    File.cd!(context.tmp_path, fn ->
      File.write!(context.paths.config_path,
        """
        import Config

        config :#{Macro.underscore(context.context_module)}, :pow,
          user: #{context.context_module}.Users.User,
          repo: #{context.context_module}.Repo
        """)

      File.write!(web_file,
        """
        defmodule PowWeb do
          def controller do
            quote do
              use Phoenix.Controller,
                formats: [:html, :json],
                layouts: [html: PowWeb.Layouts]

              import Plug.Conn
              import PowWeb.Gettext

              unquote(verified_routes())
            end
          end

          def router do
            quote do
              use Phoenix.Router, helpers: false
            end
          end

          defp html_helpers do
            quote do
              # HTML escaping functionality
              import Phoenix.HTML

              # Shortcut for generating JS commands
              alias Phoenix.LiveView.JS
            end
          end

          def verified_routes do
            quote do
              use Phoenix.VerifiedRoutes,
                endpoint: PowWeb.Endpoint,
                router: PowWeb.Router,
                statics: PowWeb.static_paths()
            end
          end
        end
        """)
    end)

    {:ok, web_file: web_file}
  end

  test "generates mailer templates", context do
    File.cd!(context.tmp_path, fn ->
      Templates.run(@options)

      for {module, expected_templates} <- @expected_templates do
        templates_path = Path.join(["lib", "pow_web", "mails"])
        content = templates_path |> Path.join(Macro.underscore(module) <> "_mail.ex") |> File.read!()

        assert content =~ "defmodule PowWeb.#{inspect(module)}Mail do"
        assert content =~ "use PowWeb, :mail"

        for expected_template <- expected_templates do
          assert content =~ "def #{expected_template}(assigns) do"
        end
      end

      assert_received {:mix_shell, :info, [@success_msg]}
      assert_received {:mix_shell, :info, ["* injecting config/config.exs"]}

      expected_config =
        """
        config :pow, :pow,
          web_mailer_module: PowWeb,
          user: Pow.Users.User,
          repo: Pow.Repo
        """

      assert File.read!("config/config.exs") =~ expected_config

      assert_received {:mix_shell, :info, ["* injecting lib/pow_web.ex"]}

      expected_content =
        """
          def mail do
            quote do
              use Pow.Phoenix.Mailer.Component

              unquote(html_helpers())
            end
          end
        """

      assert File.read!(context.web_file) =~ expected_content
    end)
  end

  test "when web file don't exist", context do
    File.cd!(context.tmp_path, fn ->
      File.rm_rf!(context.paths.config_path)
      File.rm_rf!(context.web_file)

      assert_raise Mix.Error, "Couldn't configure Pow! Did you run this inside your Phoenix app?", fn ->
        Templates.run(@options)
      end

      assert_received {:mix_shell, :error, ["Could not find the following file(s):" <> msg]}
      assert msg =~ context.paths.config_path
      assert msg =~ context.web_file
    end)
  end

  test "when web file can't be configured", context do
    File.cd!(context.tmp_path, fn ->
      File.write!(context.paths.config_path, "")
      File.write!(context.web_file, "")

      Templates.run(@options)

      assert_received {:mix_shell, :error, ["Could not configure the following files" <> msg]}
      assert msg =~ context.paths.config_path
      assert msg =~ context.web_file

      assert_received {:mix_shell, :info, ["To complete please do the following" <> msg]}
      assert msg =~ "Add `web_mailer_module: PowWeb,` to your configuration in config/config.exs:"
      assert msg =~ "config :pow, :pow,"
      assert msg =~ "web_mailer_module: PowWeb,"
      assert msg =~ "Add `mail/0` to #{context.web_file}:"
      assert msg =~ "def mail do"
      assert msg =~ "use Pow.Phoenix.Mailer.Component"
    end)
  end

  test "when web file already configured", context do
    File.cd!(context.tmp_path, fn ->
      Templates.run(@options)
      Mix.shell().flush()

      Templates.run(@options)

      for path <- [context.paths.config_path, context.web_file] do
        message = "* already configured #{path}"
        assert_received {:mix_shell, :info, [^message]}
      end

      assert_received {:mix_shell, :info, [@success_msg]}
    end)
  end

  test "warns if no extensions", context do
    File.cd!(context.tmp_path, fn ->
      Templates.run([])

      assert_received {:mix_shell, :error, ["No extensions was provided as arguments, or found in `config :pow, :pow` configuration."]}
    end)
  end

  test "warns no mailer templates", context do
    File.cd!(context.tmp_path, fn ->
      Templates.run(~w(--extension PowPersistentSession))

      assert_received {:mix_shell, :info, ["Notice: No mailer templates will be generated for PowPersistentSession as this extension doesn't have any mailer template defined."]}
    end)
  end

  describe "with extensions in env config" do
    setup do
      Application.put_env(:pow, :pow, extensions: Enum.map(@expected_templates, &elem(&1, 0)))
      on_exit(fn ->
        Application.delete_env(:pow, :pow)
      end)
    end

    test "generates mailer templates", context do
      File.cd!(context.tmp_path, fn ->
        Templates.run([])

        for {module, expected_templates} <- @expected_templates do
          templates_path = Path.join(["lib", "pow_web", "mails"])
          content = templates_path |> Path.join(Macro.underscore(module) <> "_mail.ex") |> File.read!()

          assert content =~ "defmodule PowWeb.#{inspect(module)}Mail do"
          assert content =~ "use PowWeb, :mail"

          for expected_template <- expected_templates do
            assert content =~ "def #{expected_template}(assigns) do"
          end
        end

        assert_received {:mix_shell, :info, ["* injecting lib/pow_web.ex"]}
        assert_received {:mix_shell, :info, [@success_msg]}
      end)
    end
  end
end
