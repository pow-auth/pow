defmodule Mix.Tasks.PowTest do
  use Pow.Test.Mix.TestCase

  alias Mix.Tasks.Pow

  @tmp_path Path.join(["tmp", inspect(Pow)])

  setup do
    File.rm_rf!(@tmp_path)
    File.mkdir_p!(@tmp_path)

    :ok
  end

  test "prints information" do
    File.cd!(@tmp_path, fn ->
      File.write!("mix.exs", """
      defmodule MyApp.MixProject do
        use Mix.Project

        def project do
          []
        end
      end
      """)

      Mix.Project.in_project(:my_app, ".", fn _ ->
        Pow.run([])

        assert_received {:mix_shell, :info, ["Pow v" <> _]}
      end)
    end)
  end
end
