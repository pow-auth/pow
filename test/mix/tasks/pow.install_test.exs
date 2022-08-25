defmodule Mix.Tasks.Pow.InstallTest do
  use Pow.Test.Mix.TestCase

  alias Mix.Tasks.Pow.Install

  test "generates files", context do
    File.cd!(context.tmp_path, fn ->
      Install.run([])

      assert File.ls!("lib/pow/users") == ["user.ex"]
    end)
  end

  test "with schema name and table", context do
    options = ~w(Accounts.Organization users)

    File.cd!(context.tmp_path, fn ->
      Install.run(options)

      assert_received {:mix_shell, :info, ["Pow has been installed in your Phoenix app!"]}
      assert File.read!(context.paths.config_path) =~ "user: Pow.Accounts.Organization"
    end)
  end

  test "raises error in umbrella app", context do
    File.cd!(context.tmp_path, fn ->
      File.write!("mix.exs", """
      defmodule Umbrella.MixProject do
        use Mix.Project

        def project do
          [apps_path: "apps"]
        end
      end
      """)

      Mix.Project.in_project(:umbrella, ".", fn _ ->
        assert_raise Mix.Error, ~r/mix pow.install has to be used inside an application directory/, fn ->
          Install.run([])
        end
      end)
    end)
  end

  test "raises error on invalid schema name or table", context do
    File.cd!(context.tmp_path, fn ->
      assert_raise Mix.Error, ~r/Invalid arguments/, fn ->
        Install.run(~w(Users.User))
      end

      assert_raise Mix.Error, ~r/Expected the schema argument, "users.user", to be a valid module name/, fn ->
        Install.run(~w(users.user users))
      end

      assert_raise Mix.Error, ~r/Expected the plural argument, "Users", to be all lowercase using snake_case convention/, fn ->
        Install.run(~w(Users.User Users))
      end

      assert_raise Mix.Error, ~r/Expected the plural argument, "users:", to be all lowercase using snake_case convention/, fn ->
        Install.run(~w(Users.User users:))
      end
    end)
  end
end
