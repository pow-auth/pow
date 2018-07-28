defmodule Mix.Tasks.Pow.Ecto.Gen.SchemaTest do
  use Pow.Test.Mix.TestCase

  alias Mix.Tasks.Pow.Ecto.Gen.Schema

  @tmp_path Path.join(["tmp", inspect(Schema)])
  @expected_file Path.join(["lib", "pow", "users", "user.ex"])
  @options  []

  setup do
    File.rm_rf!(@tmp_path)
    File.mkdir_p!(@tmp_path)

    :ok
  end

  test "generates schema file" do
    File.cd! @tmp_path, fn ->
      Schema.run(@options)

      assert File.exists?(@expected_file)

      content = File.read!(@expected_file)
      assert content =~ "defmodule Pow.Users.User do"
    end
  end

  test "generates with :context_app" do
    File.cd! @tmp_path, fn ->
      Schema.run(@options ++ ~w(--context-app pow))

      assert File.exists?(@expected_file)
    end
  end

  test "generates with :binary_id" do
    File.cd! @tmp_path, fn ->
      Schema.run(@options ++ ~w(--binary-id))

      assert File.exists?(@expected_file)
      file = File.read!(@expected_file)

      assert file =~ "@primary_key {:id, :binary_id, autogenerate: true}"
      assert file =~ "@foreign_key_type :binary_id"
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
