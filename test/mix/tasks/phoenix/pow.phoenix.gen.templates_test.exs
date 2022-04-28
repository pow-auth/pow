defmodule Mix.Tasks.Pow.Phoenix.Gen.TemplatesTest do
  use Pow.Test.Mix.TestCase

  alias Mix.Tasks.Pow.Phoenix.Gen.Templates

  @tmp_path Path.join(["tmp", inspect(Templates)])

  @expected_msg "Pow Phoenix templates and views has been generated."
  @expected_template_files %{
    "registration" => ["edit.html.eex", "new.html.eex"],
    "session" => ["new.html.eex"]
  }
  @expected_views Map.keys(@expected_template_files)

  setup do
    File.rm_rf!(@tmp_path)
    File.mkdir_p!(@tmp_path)

    :ok
  end

  test "generates templates" do
    File.cd!(@tmp_path, fn ->
      Templates.run([])

      templates_path = Path.join(["lib", "pow_web", "templates", "pow"])
      expected_dirs  = Map.keys(@expected_template_files)

      assert ls(templates_path) == expected_dirs

      for {dir, expected_files} <- @expected_template_files do
        files = templates_path |> Path.join(dir) |> ls()
        assert files == expected_files
      end

      views_path          = Path.join(["lib", "pow_web", "views", "pow"])
      expected_view_files = Enum.map(@expected_views, &"#{&1}_view.ex")
      view_content        = views_path |> Path.join("session_view.ex") |> File.read!()

      assert ls(views_path) == expected_view_files
      assert view_content =~ "defmodule PowWeb.Pow.SessionView do"
      assert view_content =~ "use PowWeb, :view"

      assert_received {:mix_shell, :info, [@expected_msg <> msg]}
      assert msg =~ "config :pow, :pow,"
      assert msg =~ "user: Pow.Users.User,"
      assert msg =~ "repo: Pow.Repo,"
      assert msg =~ "web_module: PowWeb"
    end)
  end

  describe "with `:web_module` environment config set" do
    setup do
      Application.put_env(:pow, :pow, web_module: PowWeb)
      on_exit(fn ->
        Application.delete_env(:pow, :pow)
      end)
    end

    test "doesn't print web_module instructions" do
      File.cd!(@tmp_path, fn ->
        Templates.run([])

        refute_received {:mix_shell, :info, [@expected_msg <> _msg]}
      end)
    end
  end

  test "generates with `:context_app`" do
    options = ~w(--context-app my_app)

    File.cd!(@tmp_path, fn ->
      Templates.run(options)

      assert_received {:mix_shell, :info, [@expected_msg <> msg]}
      assert msg =~ "config :pow, :pow,"
      assert msg =~ "user: MyApp.Users.User,"
      assert msg =~ "repo: MyApp.Repo,"
    end)
  end

  test "generates with `:generators` config" do
    Application.put_env(:pow, :generators, context_app: {:my_app, "my_app"})
    on_exit(fn ->
      Application.delete_env(:pow, :generators)
    end)

    File.cd!(@tmp_path, fn ->
      Templates.run([])

      assert_received {:mix_shell, :info, [@expected_msg <> msg]}
      assert msg =~ "config :pow, :pow,"
      assert msg =~ "user: MyApp.Users.User,"
      assert msg =~ "repo: MyApp.Repo,"
    end)
  end

  defp ls(path), do: path |> File.ls!() |> Enum.sort()
end
