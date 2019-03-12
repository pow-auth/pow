defmodule Mix.Tasks.Pow.Extension.Phoenix.Mailer.Gen.TemplatesTest do
  use Pow.Test.Mix.TestCase

  alias Mix.Tasks.Pow.Extension.Phoenix.Mailer.Gen.Templates

  @tmp_path Path.join(["tmp", inspect(Templates)])
  @expected_msg "Pow mailer templates has been installed in your phoenix app!"
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

  setup do
    File.rm_rf!(@tmp_path)
    File.mkdir_p!(@tmp_path)

    :ok
  end

  test "generates mailer templates" do
    Mix.shell().flush

    File.cd!(@tmp_path, fn ->
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

      assert_receive {:mix_shell, :info, [@expected_msg <> msg]}
      assert msg =~ "lib/pow_web.ex"
      assert msg =~ "`mailer_view/0`"
      assert msg =~ "def mailer_view"
      assert msg =~ "use Phoenix.View, root: \"lib/pow_web/templates\""
    end)
  end

  test "warns if no extensions" do
    File.cd!(@tmp_path, fn ->
      Templates.run([])

      assert_received {:mix_shell, :error, ["No extensions was provided as arguments, or found in `config :pow, :pow` configuration."]}
    end)
  end

  describe "with extensions in env config" do
    setup do
      Application.put_env(:pow, :pow, extensions: Enum.map(@expected_template_files, &elem(&1, 0)))
      on_exit(fn ->
        Application.delete_env(:pow, :pow)
      end)
    end

    test "generates mailer templates" do
      File.cd!(@tmp_path, fn ->
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

        assert_received {:mix_shell, :info, [@expected_msg <> msg]}
        assert msg =~ "lib/pow_web.ex"
        assert msg =~ "`mailer_view/0`"
        assert msg =~ "def mailer_view"
        assert msg =~ "use Phoenix.View, root: \"lib/pow_web/templates\""
      end)
    end
  end

  defp ls(path), do: path |> File.ls!() |> Enum.sort()
end
