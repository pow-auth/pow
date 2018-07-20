defmodule Mix.Tasks.Pow.Ecto.Gen.SchemaTest do
  use Pow.Test.Mix.TestCase

  alias Mix.Tasks.Pow.Ecto.Gen.Schema

  @tmp_path Path.join(["tmp", inspect(Schema)])
  @options  ["--no-migrations"]

  setup do
    File.rm_rf!(@tmp_path)
    File.mkdir_p!(@tmp_path)

    :ok
  end

  test "generates schema file" do
    File.cd! @tmp_path, fn ->
      Schema.run(@options)

      path = Path.join(["lib", "pow", "users"])
      file = "user.ex"

      assert File.ls!(path) == [file]

      content = File.read!(Path.join(path, file))

      assert content =~ "defmodule Pow.Users.User do"
    end
  end

  test "generates with :context_app" do
    File.cd! @tmp_path, fn ->
      Schema.run(@options ++ ~w(--context-app pow))

      path = Path.join(["lib", "pow", "users"])
      assert File.ls!(path) == ["user.ex"]
    end
  end

  test "doesn't make duplicate files" do
    File.cd! @tmp_path, fn ->
      Schema.run(@options)

      assert_raise Mix.Error, "schema file can't be created, there is already a schema file in lib/pow/users/user.ex.", fn ->
        Schema.run(@options)
      end
    end
  end
end
