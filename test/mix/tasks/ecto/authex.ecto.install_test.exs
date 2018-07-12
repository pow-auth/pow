defmodule Mix.Tasks.Authex.Ecto.InstallTest do
  use Authex.Test.Mix.TestCase

  alias Mix.Tasks.Authex.Ecto.Install

  defmodule Repo do
    def __adapter__, do: true
    def config, do: [priv: "", otp_app: :authex]
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

      assert File.ls!("lib/authex/users") == ["user.ex"]
      assert [_one] = File.ls!("migrations")
    end
  end
end
