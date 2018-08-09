defmodule Mix.Tasks.Pow.Ecto.InstallTest do
  use Pow.Test.Mix.TestCase

  alias Mix.Tasks.Pow.Ecto.Install

  defmodule Repo do
    def __adapter__, do: true
    def config, do: [priv: "", otp_app: :pow]
  end

  @tmp_path Path.join(["tmp", inspect(Install)])
  @options  ["-r", inspect(Repo)]

  setup do
    File.rm_rf!(@tmp_path)
    File.mkdir_p!(@tmp_path)

    :ok
  end

  test "generates files" do
    File.cd! @tmp_path, fn ->
      Install.run(@options)

      assert File.ls!("lib/pow/users") == ["user.ex"]
      assert [_one] = File.ls!("migrations")
    end
  end

  test "generates with schema name and table" do
    File.cd! @tmp_path, fn ->
      Install.run(@options ++ ~w(Organizations.Organization organizations) ++ ~w(--extension PowResetPassword --extension PowEmailConfirmation))

      assert File.ls!("lib/pow/organizations") == ["organization.ex"]
      assert [one, two] = Enum.sort(File.ls!("migrations"))
      assert one =~ "_create_organizations.exs"
      assert two =~ "_add_pow_email_confirmation_to_organizations.exs"

      content = File.read!("migrations/#{one}")
      assert content =~ "table(:organizations)"

      content = File.read!("migrations/#{two}")
      assert content =~ "table(:organizations)"
    end
  end

  test "generates with extensions" do
    File.cd! @tmp_path, fn ->
      Install.run(@options ++ ~w(--extension PowResetPassword --extension PowEmailConfirmation))

      assert File.ls!("lib/pow/users") == ["user.ex"]
      assert [one, two] = Enum.sort(File.ls!("migrations"))
      assert one =~ "_create_users.exs"
      assert two =~ "_add_pow_email_confirmation_to_users.exs"
    end
  end
end
