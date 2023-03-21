defmodule Mix.Tasks.Pow.Phoenix.Gen.TemplatesTest do
  use Pow.Test.Mix.TestCase

  alias Mix.Tasks.Pow.Phoenix.Gen.Templates

  @success_msg "Pow Phoenix templates has been generated."

  @expected_template_files %{
    "registration_html" => ["edit.html.heex", "new.html.heex"],
    "session_html" => ["new.html.heex"]
  }

  setup context do
    File.cd!(context.tmp_path, fn ->
      File.write!(context.paths.config_path,
        """
        import Config

        config :#{Macro.underscore(context.context_module)}, :pow,
          user: #{context.context_module}.Users.User,
          repo: #{context.context_module}.Repo
        """)
    end)

    :ok
  end

  test "generates templates", context do
    File.cd!(context.tmp_path, fn ->
      Templates.run([])

      templates_path = Path.join(["lib", "pow_web", "controllers", "pow"])
      expected_dirs  = Map.keys(@expected_template_files)
      expected_files = Enum.map(expected_dirs, &"#{&1}.ex")

      assert expected_dirs -- ls(templates_path) == []
      assert expected_files -- ls(templates_path) == []

      for {dir, expected_files} <- @expected_template_files do
        files = templates_path |> Path.join(dir) |> ls()

        assert expected_files -- files == []
      end

      for base_name <- expected_dirs do
        content     = templates_path |> Path.join(base_name <> ".ex") |> File.read!()
        module_name = base_name |> Macro.camelize() |> String.replace_suffix("Html", "HTML")

        assert content =~ "defmodule PowWeb.Pow.#{module_name} do"
        assert content =~ "use PowWeb, :html"
        assert content =~ "embed_templates \"#{base_name}/*\""
      end

      assert_received {:mix_shell, :info, ["* injecting config/config.exs"]}
      assert_received {:mix_shell, :info, [@success_msg]}

      expected_config =
        """
        config :pow, :pow,
          web_module: PowWeb,
          user: Pow.Users.User,
          repo: Pow.Repo
        """

      assert File.read!("config/config.exs") =~ expected_config
    end)
  end

  test "when config file don't exist", context do
    File.cd!(context.tmp_path, fn ->
      File.rm_rf!(context.paths.config_path)

      assert_raise Mix.Error, "Couldn't configure Pow! Did you run this inside your Phoenix app?", fn ->
        Templates.run([])
      end

      assert_received {:mix_shell, :error, ["Could not find the following file(s):" <> msg]}
      assert msg =~ context.paths.config_path
    end)
  end

  test "when config file can't be configured", context do
    File.cd!(context.tmp_path, fn ->
      File.write!(context.paths.config_path, "")

      Templates.run([])

      assert_received {:mix_shell, :error, ["Could not configure the following files" <> msg]}
      assert msg =~ context.paths.config_path

      assert_received {:mix_shell, :info, ["To complete please do the following" <> msg]}
      assert msg =~ "Add `web_module: PowWeb,` to your configuration in config/config.exs:"
      assert msg =~ "config :pow, :pow,"
      assert msg =~ "web_module: PowWeb,"
    end)
  end

  test "when config file already configured", context do
    File.cd!(context.tmp_path, fn ->
      Templates.run([])
      Mix.shell().flush()

      Templates.run([])

      message = "* already configured #{context.paths.config_path}"
      assert_received {:mix_shell, :info, [^message]}

      assert_received {:mix_shell, :info, [@success_msg]}
    end)
  end

  test "generates instructions with `:context_app`", context do
    options = ~w(--context-app my_app)

    File.cd!(context.tmp_path, fn ->
      File.write!(context.paths.config_path, "")

      Templates.run(options)

      assert_received {:mix_shell, :info, ["To complete please do the following" <> msg]}
      assert msg =~ "Add `web_module: Pow,` to your configuration in config/config.exs:"
      assert msg =~ "config :pow, :pow,"
      assert msg =~ "web_module: Pow,"
      assert msg =~ "user: MyApp.Users.User,"
    end)
  end

  test "generates instructions with `:generators` config", context do
    Application.put_env(:pow, :generators, context_app: {:my_app, "my_app"})
    on_exit(fn ->
      Application.delete_env(:pow, :generators)
    end)

    File.cd!(context.tmp_path, fn ->
      File.write!(context.paths.config_path, "")

      Templates.run([])

      assert_received {:mix_shell, :info, ["To complete please do the following" <> msg]}
      assert msg =~ "Add `web_module: Pow,` to your configuration in config/config.exs:"
      assert msg =~ "config :pow, :pow,"
      assert msg =~ "web_module: Pow,"
      assert msg =~ "user: MyApp.Users.User,"
    end)
  end

  defp ls(path), do: path |> File.ls!() |> Enum.sort()
end
