defmodule Mix.Tasks.Pow.Extension.Phoenix.Gen.TemplatesTest do
  use Pow.Test.Mix.TestCase

  alias Mix.Tasks.Pow.Extension.Phoenix.Gen.Templates

  @tmp_path Path.join(["tmp", inspect(Templates)])
  @expected_template_files [
    {PowResetPassword, %{
      "reset_password" => ["edit.html.eex", "new.html.eex"]
    }},
    {PowInvitation, %{
      "invitation" => ["edit.html.eex", "new.html.eex", "show.html.eex"]
    }}
  ]
  @options Enum.flat_map(@expected_template_files, &["--extension", inspect(elem(&1, 0))])

  setup do
    File.rm_rf!(@tmp_path)
    File.mkdir_p!(@tmp_path)

    :ok
  end

  test "generates templates" do
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

        [base_name | _rest] = expected_templates |> Map.keys()
        view_content        = views_path |> Path.join(base_name <> "_view.ex") |> File.read!()

        assert view_content =~ "defmodule PowWeb.#{inspect(module)}.#{Macro.camelize(base_name)}View do"
        assert view_content =~ "use PowWeb, :view"
      end
    end)
  end

  test "warns if no extensions" do
    File.cd!(@tmp_path, fn ->
      Templates.run([])

      assert_received {:mix_shell, :error, ["No extensions was provided as arguments, or found in `config :pow, :pow` configuration."]}
    end)
  end

  describe "with `:context_app` configuration" do
    setup do
      Application.put_env(:test, :pow, extensions: Enum.map(@expected_template_files, &elem(&1, 0)))
      on_exit(fn ->
        Application.delete_env(:test, :pow)
      end)
    end

    test "generates templates" do
      File.cd!(@tmp_path, fn ->
        Templates.run(~w(--context-app test))

        for {module, expected_templates} <- @expected_template_files do
          templates_path = Path.join(["lib", "test_web", "templates", Macro.underscore(module)])
          dirs           = templates_path |> File.ls!() |> Enum.sort()

          assert dirs == Map.keys(expected_templates)

          views_path = Path.join(["lib", "test_web", "views", Macro.underscore(module)])

          [base_name | _rest] = expected_templates |> Map.keys()
          view_content        = views_path |> Path.join(base_name <> "_view.ex") |> File.read!()

          assert view_content =~ "defmodule TestWeb.#{inspect(module)}.#{Macro.camelize(base_name)}View do"
          assert view_content =~ "use TestWeb, :view"
        end
      end)
    end
  end

  defp ls(path), do: path |> File.ls!() |> Enum.sort()
end
