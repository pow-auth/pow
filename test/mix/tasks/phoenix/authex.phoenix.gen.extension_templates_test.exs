defmodule Mix.Tasks.Authex.Phoenix.Gen.ExtensionTemplatesTest do
  use Authex.Test.Mix.TestCase

  alias Mix.Tasks.Authex.Phoenix.Gen.ExtensionTemplates

  @tmp_path Path.join(["tmp", inspect(ExtensionTemplates)])
  @options []

  @expected_template_files [
    {AuthexResetPassword, %{
      "reset_password" => ["edit.html.eex", "new.html.eex"]
    }}
  ]

  setup do
    File.rm_rf!(@tmp_path)
    File.mkdir_p!(@tmp_path)

    :ok
  end

  test "generates templates" do
    File.cd! @tmp_path, fn ->
      ExtensionTemplates.run(@options)
      for {module, expected_templates} <- @expected_template_files do
        templates_path = Path.join(["lib", "authex_web", "templates", Macro.underscore(module)])
        expected_dirs  = Map.keys(expected_templates)

        assert ls(templates_path) == expected_dirs

        for {dir, expected_files} <- expected_templates do
          files = templates_path |> Path.join(dir) |> ls()
          assert files == expected_files
        end

        views_path          = Path.join(["lib", "authex_web", "views", Macro.underscore(module)])
        expected_view_files = expected_templates |> Map.keys() |> Enum.map(&"#{&1}_view.ex")

        assert ls(views_path) == expected_view_files

        [base_name | _rest] = expected_templates |> Map.keys()
        view_content        = views_path |> Path.join(base_name <> "_view.ex") |> File.read!()

        assert view_content =~ "defmodule AuthexWeb.#{inspect module}.#{Macro.camelize(base_name)}View do"
        assert view_content =~ "use AuthexWeb, :view"
      end
    end
  end

  test "generates with :context_app" do
    File.cd! @tmp_path, fn ->
      ExtensionTemplates.run(@options ++ ~w(--context-app test))

      for {module, expected_templates} <- @expected_template_files do
        templates_path = Path.join(["lib", "test_web", "templates", Macro.underscore(module)])
        dirs           = templates_path |> File.ls!() |> Enum.sort()

        assert dirs == Map.keys(expected_templates)

        views_path          = Path.join(["lib", "test_web", "views", Macro.underscore(module)])

        [base_name | _rest] = expected_templates |> Map.keys()
        view_content        = views_path |> Path.join(base_name <> "_view.ex") |> File.read!()

        assert view_content =~ "defmodule TestWeb.#{inspect module}.#{Macro.camelize(base_name)}View do"
        assert view_content =~ "use TestWeb, :view"
      end
    end
  end

  defp ls(path), do: path |> File.ls!() |> Enum.sort()
end
