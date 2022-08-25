defmodule Mix.Tasks.Pow.Extension.Phoenix.Gen.TemplatesTest do
  use Pow.Test.Mix.TestCase

  alias Mix.Tasks.Pow.Extension.Phoenix.Gen.Templates

  @expected_template_files [
    {PowResetPassword, %{
      "reset_password" => ["edit.html.eex", "new.html.eex"]
    }},
    {PowInvitation, %{
      "invitation" => ["edit.html.eex", "new.html.eex", "show.html.eex"]
    }}
  ]
  @options Enum.flat_map(@expected_template_files, &["--extension", inspect(elem(&1, 0))])

  test "generates templates", context do
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

        [base_name | _rest] = expected_templates |> Map.keys()
        view_content        = views_path |> Path.join(base_name <> "_view.ex") |> File.read!()

        assert view_content =~ "defmodule PowWeb.#{inspect(module)}.#{Macro.camelize(base_name)}View do"
        assert view_content =~ "use PowWeb, :view"
      end
    end)
  end

  test "warns if no extensions", context do
    File.cd!(context.tmp_path, fn ->
      Templates.run([])

      assert_received {:mix_shell, :error, ["No extensions was provided as arguments, or found in `config :pow, :pow` configuration."]}
    end)
  end

  test "warns no templates", context do
    File.cd!(context.tmp_path, fn ->
      Templates.run(~w(--extension PowPersistentSession))

      assert_received {:mix_shell, :info, ["Notice: No view or template files will be generated for PowPersistentSession as this extension doesn't have any views defined."]}
    end)
  end

  describe "with extensions in env config" do
    setup do
      Application.put_env(:pow, :pow, extensions: Enum.map(@expected_template_files, &elem(&1, 0)))
      on_exit(fn ->
        Application.delete_env(:pow, :pow)
      end)
    end

    test "generates templates", context do
      File.cd!(context.tmp_path, fn ->
        Templates.run([])

        for {module, expected_templates} <- @expected_template_files do
          templates_path = Path.join(["lib", "pow_web", "templates", Macro.underscore(module)])
          dirs           = templates_path |> File.ls!() |> Enum.sort()

          assert dirs == Map.keys(expected_templates)

          views_path = Path.join(["lib", "pow_web", "views", Macro.underscore(module)])

          [base_name | _rest] = expected_templates |> Map.keys()
          view_content        = views_path |> Path.join(base_name <> "_view.ex") |> File.read!()

          assert view_content =~ "defmodule PowWeb.#{inspect(module)}.#{Macro.camelize(base_name)}View do"
          assert view_content =~ "use PowWeb, :view"
        end
      end)
    end
  end

  defp ls(path), do: path |> File.ls!() |> Enum.sort()

  # This is for insurance that all available templates are being tested
  test "test all templates" do
    expected      = Enum.into(@expected_template_files, %{})
    all_templates =
      "lib/extensions"
      |> File.ls!()
      |> Enum.filter(&File.dir?("lib/extensions/#{&1}/phoenix/views"))
      |> Enum.map(fn dir ->
        extension = Module.concat(["Pow#{Macro.camelize(dir)}"])
        templates =
          "lib/extensions/#{dir}/phoenix/views"
          |> File.ls!()
          |> Enum.map(&String.replace(&1, "_view.ex", ""))

        {extension, templates}
      end)

    for {extension, templates} <- all_templates do
      assert Map.has_key?(expected, extension), "Missing template tests for #{inspect(extension)} extension"
      assert Map.keys(expected[extension]) == templates, "Not all templates are tested for the #{inspect(extension)} extension"
    end
  end
end
