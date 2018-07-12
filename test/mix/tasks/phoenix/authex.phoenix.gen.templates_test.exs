defmodule Mix.Tasks.Authex.Phoenix.Gen.TemplatesTest do
  use Authex.Test.Mix.TestCase

  alias Mix.Tasks.Authex.Phoenix.Gen.Templates

  @tmp_path Path.join(["tmp", inspect(Templates)])
  @options []

  @expected_template_files %{
    "registration" => ["edit.html.eex", "new.html.eex", "show.html.eex"],
    "session" => ["new.html.eex"]
  }
  @expected_views @expected_template_files |> Map.keys()

  setup do
    File.rm_rf!(@tmp_path)
    File.mkdir_p!(@tmp_path)

    :ok
  end

  test "generates schema file" do
    File.cd! @tmp_path, fn ->
      Templates.run(@options)
      templates_path = Path.join(["lib", "authex_web", "templates", "authex"])
      expected_dirs  = Map.keys(@expected_template_files)

      assert ls(templates_path) == expected_dirs

      for {dir, expected_files} <- @expected_template_files do
        files = templates_path |> Path.join(dir) |> ls()
        assert files == expected_files
      end

      views_path          = Path.join(["lib", "authex_web", "views", "authex"])
      expected_view_files = Enum.map(@expected_views, &"#{&1}_view.ex")
      view_content        = views_path |> Path.join("session_view.ex") |> File.read!()

      assert ls(views_path) == expected_view_files
      assert view_content =~ "defmodule AuthexWeb.Authex.SessionView do"
      assert view_content =~ "use AuthexWeb, :view"

      for _ <- 1..6, do: assert_received {:mix_shell, :info, [_msg]}
      assert_received {:mix_shell, :info, [msg]}
      assert msg =~ "defmodule AuthexWeb.Endpoint"
      assert msg =~ "otp_app: :authex"
      assert msg =~ "repo: Authex.Repo"
      assert msg =~ "user: Authex.Users.User"
      assert msg =~ "context_app: AuthexWeb"
    end
  end

  test "generates with :context_app" do
    File.cd! @tmp_path, fn ->
      Templates.run(@options ++ ~w(--context-app test))

      templates_path = Path.join(["lib", "test_web", "templates", "authex"])
      dirs           = templates_path |> File.ls!() |> Enum.sort()

      assert dirs == Map.keys(@expected_template_files)

      views_path          = Path.join(["lib", "test_web", "views", "authex"])
      view_content        = views_path |> Path.join("session_view.ex") |> File.read!()

      assert view_content =~ "defmodule TestWeb.Authex.SessionView do"
      assert view_content =~ "use TestWeb, :view"

      for _ <- 1..6, do: assert_received {:mix_shell, :info, [_msg]}
      assert_received {:mix_shell, :info, [msg]}
      assert msg =~ "defmodule TestWeb.Endpoint"
      assert msg =~ "otp_app: :test"
      assert msg =~ "repo: Test.Repo"
      assert msg =~ "user: Test.Users.User"
      assert msg =~ "context_app: TestWeb"
    end
  end

  defp ls(path), do: path |> File.ls!() |> Enum.sort()
end
