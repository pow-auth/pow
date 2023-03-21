defmodule Mix.Tasks.Pow.Extension.Phoenix.Gen.TemplatesTest do
  use Pow.Test.Mix.TestCase

  alias Mix.Tasks.Pow.Extension.Phoenix.Gen.Templates

  @expected_template_files [
    {PowResetPassword, %{
      "reset_password_html" => ["edit.html.heex", "new.html.heex"]
    }},
    {PowInvitation, %{
      "invitation_html" => ["edit.html.heex", "new.html.heex", "show.html.heex"]
    }}
  ]
  @options Enum.flat_map(@expected_template_files, &["--extension", inspect(elem(&1, 0))])

  test "generates templates", context do
    File.cd!(context.tmp_path, fn ->
      Templates.run(@options)

      for {module, expected_templates} <- @expected_template_files do
        templates_path = Path.join(["lib", "pow_web", "controllers", Macro.underscore(module)])
        expected_dirs  = Map.keys(expected_templates)
        expected_files = Enum.map(expected_dirs, &"#{&1}.ex")

        assert expected_dirs -- ls(templates_path) == []
        assert expected_files -- ls(templates_path) == []

        for {dir, expected_files} <- expected_templates do
          files = templates_path |> Path.join(dir) |> ls()

          assert expected_files -- files == []
        end

        for base_name <- expected_dirs do
          content     = templates_path |> Path.join(base_name <> ".ex") |> File.read!()
          module_name = base_name |> Macro.camelize() |> String.replace_suffix("Html", "HTML")

          assert content =~ "defmodule PowWeb.#{inspect(module)}.#{module_name} do"
          assert content =~ "use PowWeb, :html"
          assert content =~ "embed_templates \"#{base_name}/*\""
        end
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

      assert_received {:mix_shell, :info, ["Notice: No template files will be generated for PowPersistentSession as this extension doesn't have any templates defined."]}
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
          templates_path = Path.join(["lib", "pow_web", "controllers", Macro.underscore(module)])
          dirs           = templates_path |> File.ls!() |> Enum.sort()

          assert Map.keys(expected_templates) -- dirs == []

          [base_name] = expected_templates |> Map.keys()
          content     = templates_path |> Path.join(base_name <> ".ex") |> File.read!()
          module_name = base_name |> Macro.camelize() |> String.replace_suffix("Html", "HTML")

          assert content =~ "defmodule PowWeb.#{inspect(module)}.#{module_name} do"
          assert content =~ "use PowWeb, :html"
          assert content =~ "embed_templates \"#{base_name}/*\""
        end
      end)
    end
  end

  defp ls(path), do: path |> File.ls!() |> Enum.sort()

  # This is for insurance that all available templates are being tested
  test "test all templates" do
    expected = Enum.into(@expected_template_files, %{})

    for extension_dir <- File.ls!("lib/extensions"),
        File.dir?("lib/extensions/#{extension_dir}/phoenix/controllers"),
        template <- Enum.filter(File.ls!("lib/extensions/#{extension_dir}/phoenix/controllers"), &String.ends_with?(&1, "_html.ex")) do
      module = Module.concat(["Pow#{Macro.camelize(extension_dir)}"])
      template = String.replace_suffix(template, ".ex", "")

      assert Map.has_key?(expected, module), "Missing template tests for #{inspect(module)} extension"
      assert template in Map.keys(expected[module]), "Not all templates are tested for the #{inspect(module)} extension"
    end
  end
end
