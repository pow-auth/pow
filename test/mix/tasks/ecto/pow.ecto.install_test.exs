defmodule Mix.Tasks.Pow.Ecto.InstallTest do
  use Pow.Test.Mix.TestCase

  alias Mix.Tasks.Pow.Ecto.Install

  defmodule Repo do
    def __adapter__, do: true
    def config, do: [priv: "./", otp_app: :pow]
  end

  @options ["-r", inspect(Repo)]
  @migrations_path "migrations"

  test "generates files", context do
    File.cd!(context.tmp_path, fn ->
      Install.run(@options)

      assert File.ls!("lib/pow/users") == ["user.ex"]
      assert [_one] = File.ls!(@migrations_path)
    end)
  end

  test "generates with schema name and table", context do
    options = @options ++ ~w(Organizations.Organization organizations --extension PowResetPassword --extension PowEmailConfirmation)

    File.cd!(context.tmp_path, fn ->
      Install.run(options)

      assert File.ls!("lib/pow/organizations") == ["organization.ex"]
      assert [one, two] = Enum.sort(File.ls!(@migrations_path))
      assert one =~ "_create_organizations.exs"
      assert two =~ "_add_pow_email_confirmation_to_organizations.exs"

      content = File.read!(Path.join(@migrations_path, one))
      assert content =~ "table(:organizations)"

      content = File.read!(Path.join(@migrations_path, two))
      assert content =~ "table(:organizations)"
    end)
  end

  test "generates with extensions", context do
    options = @options ++ ~w(--extension PowResetPassword --extension PowEmailConfirmation)

    File.cd!(context.tmp_path, fn ->
      Install.run(options)

      assert File.ls!("lib/pow/users") == ["user.ex"]
      assert [one, two] = Enum.sort(File.ls!(@migrations_path))
      assert one =~ "_create_users.exs"
      assert two =~ "_add_pow_email_confirmation_to_users.exs"
    end)
  end

  test "raises error in app with no ecto dep", context do
    File.cd!(context.tmp_path, fn ->
      File.write!("mix.exs", """
      defmodule MissingTopLevelEctoDep.MixProject do
        use Mix.Project

        def project do
          [
            app: :missing_top_level_ecto_dep,
            deps: [
              {:ecto_dep, path: "ecto_dep/"}
            ]
          ]
        end
      end
      """)
      File.mkdir!("ecto_dep")
      File.write!("ecto_dep/mix.exs", """
      defmodule EctoDep.MixProject do
        use Mix.Project

        def project do
          [
            app: :ecto_dep,
            deps: [{:ecto_sql, ">= 0.0.0"}]
          ]
        end
      end
      """)

      Mix.Project.in_project(:missing_top_level_ecto_dep, ".", fn _ ->
        # Insurance that we do test for top level ecto inclusion
        assert Enum.any?(Mix.Dep.load_on_environment([]), fn
          %{app: :ecto_sql} -> true
          _ -> false
        end), "Ecto not loaded by dependency"

        assert_raise Mix.Error, "mix pow.ecto.install can only be run inside an application directory that has :ecto or :ecto_sql as dependency", fn ->
          Install.run([])
        end
      end)
    end)
  end

  describe "with `:namespace` environment config set" do
    setup do
      Application.put_env(:pow, :namespace, POW)
      on_exit(fn ->
        Application.delete_env(:pow, :namespace)
      end)
    end

    test "uses namespace for context module names", context do
      File.cd!(context.tmp_path, fn ->
        Install.run(@options)

        assert File.read!("lib/pow/users/user.ex") =~ "defmodule POW.Users.User do"
      end)
    end
  end
end
