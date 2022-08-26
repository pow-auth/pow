defmodule Mix.Tasks.Pow.Extension.Phoenix.Mailer.Gen.TemplatesTest do
  use Pow.Test.Mix.TestCase

  alias Mix.Tasks.Pow.Extension.Phoenix.Mailer.Gen.Templates

  @success_msg "Pow mailer templates has been installed in your phoenix app!"
  @expected_template_files [
    {PowResetPassword, %{
      "mailer" => ["reset_password.html.eex", "reset_password.text.eex"]
    }},
    {PowEmailConfirmation, %{
      "mailer" => ["email_confirmation.html.eex", "email_confirmation.text.eex"]
    }},
    {PowInvitation, %{
      "mailer" => ["invitation.html.eex", "invitation.text.eex"]
    }}
  ]
  @options Enum.flat_map(@expected_template_files, &["--extension", inspect(elem(&1, 0))])

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
              use Phoenix.Controller, namespace: FrontlineWeb
            end
          end

          def view do
            quote do
              use Phoenix.View,
                root: "lib/frontline_web/templates",
                namespace: FrontlineWeb
            end
          end

          def router do
            quote do
              use Phoenix.Router
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

      for {module, expected_templates} <- @expected_template_files do
        templates_path = Path.join(["lib", "pow_web", "templates", Macro.underscore(module)])
        expected_dirs  = Map.keys(expected_templates)

        assert ls(templates_path) == expected_dirs

        for {dir, expected_files} <- expected_templates do
          files = templates_path |> Path.join(dir) |> ls()
          assert files == expected_files
        end

        views_path          = Path.join(["lib", "pow_web", "views", Macro.underscore(module)])
        expected_view_files = expected_templates |> Map.keys() |> Enum.map(&"#{&1}_view.ex")

        assert ls(views_path) == expected_view_files

        [base_name | _rest] = expected_templates |> Map.keys() |> Enum.sort()
        view_content        = views_path |> Path.join(base_name <> "_view.ex") |> File.read!()

        assert view_content =~ "defmodule PowWeb.#{inspect(module)}.#{Macro.camelize(base_name)}View do"
        assert view_content =~ "use PowWeb, :mailer_view"

        template =
          expected_templates
          |> Map.get(base_name)
          |> List.first()
          |> String.split(".html.eex")

        assert view_content =~ "def subject(:#{template}, _assigns), do:"
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
          def mailer_view do
            quote do
              use Phoenix.View, root: "lib/pow_web/templates",
                                namespace: PowWeb

              use Phoenix.HTML
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
      assert msg =~ "Add `mailer_view/0` to #{context.web_file}:"
      assert msg =~ "def mailer_view do"
      assert msg =~ "use Phoenix.View, root: \"lib/pow_web/templates\","
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

      assert_received {:mix_shell, :info, ["Notice: No mailer view or template files will be generated for PowPersistentSession as this extension doesn't have any mailer views defined."]}
    end)
  end

  describe "with extensions in env config" do
    setup do
      Application.put_env(:pow, :pow, extensions: Enum.map(@expected_template_files, &elem(&1, 0)))
      on_exit(fn ->
        Application.delete_env(:pow, :pow)
      end)
    end

    test "generates mailer templates", context do
      File.cd!(context.tmp_path, fn ->
        Templates.run([])

        for {module, expected_templates} <- @expected_template_files do
          templates_path = Path.join(["lib", "pow_web", "templates", Macro.underscore(module)])
          dirs           = templates_path |> File.ls!() |> Enum.sort()

          assert dirs == Map.keys(expected_templates)

          views_path          = Path.join(["lib", "pow_web", "views", Macro.underscore(module)])
          [base_name | _rest] = expected_templates |> Map.keys()
          view_content        = views_path |> Path.join(base_name <> "_view.ex") |> File.read!()

          assert view_content =~ "defmodule PowWeb.#{inspect(module)}.#{Macro.camelize(base_name)}View do"
          assert view_content =~ "use PowWeb, :mailer_view"
        end

        assert_received {:mix_shell, :info, ["* injecting lib/pow_web.ex"]}
        assert_received {:mix_shell, :info, [@success_msg]}
      end)
    end
  end

  defp ls(path), do: path |> File.ls!() |> Enum.sort()
end
