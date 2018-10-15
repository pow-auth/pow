defmodule Mix.Tasks.Pow.InstallTest do
  use Pow.Test.Mix.TestCase

  alias Mix.Tasks.Pow.Install

  @tmp_path Path.join(["tmp", inspect(Install)])

  setup do
    File.rm_rf!(@tmp_path)
    File.mkdir_p!(@tmp_path)

    :ok
  end

  test "generates files" do
    options = ~w(--context-app pow)

    File.cd!(@tmp_path, fn ->
      Install.run(options)

      assert File.ls!("lib/pow/users") == ["user.ex"]
    end)
  end

  test "raises error in umbrella app" do
    File.cd!(@tmp_path, fn ->
      File.write!("mix.exs", """
      defmodule Umbrella.MixProject do
        use Mix.Project

        def project do
          [apps_path: "apps"]
        end
      end
      """)

      Mix.Project.in_project(:umbrella, ".", fn _ ->
        assert_raise Mix.Error, "mix pow.install can't be used in umbrella apps. Run mix pow.ecto.install in your ecto app directory, and mix pow.phoenix.install in your phoenix app directory.", fn ->
          Install.run([])
        end
      end)
    end)
  end
end
