defmodule Mix.Tasks.Pow.Ecto.Gen.SchemaTest do
  use Pow.Test.Mix.TestCase

  alias Mix.Tasks.Pow.Ecto.Gen.Schema

  @expected_file Path.join(["lib", "pow", "users", "user.ex"])

  test "generates schema file", context do
    File.cd!(context.tmp_path, fn ->
      Schema.run([])

      assert File.exists?(@expected_file)

      content = File.read!(@expected_file)
      assert content =~ "defmodule Pow.Users.User do"
    end)
  end

  test "generates with `:binary_id` and `:context_app`", context do
    options = ~w(--binary-id --context-app pow)

    File.cd!(context.tmp_path, fn ->
      Schema.run(options)

      assert File.exists?(@expected_file)
      file = File.read!(@expected_file)

      assert file =~ "@primary_key {:id, :binary_id, autogenerate: true}"
      assert file =~ "@foreign_key_type :binary_id"
    end)
  end

  test "doesn't make duplicate files", context do
    File.cd!(context.tmp_path, fn ->
      Schema.run([])

      assert_raise Mix.Error, "schema file can't be created, there is already a schema file in lib/pow/users/user.ex.", fn ->
        Schema.run([])
      end
    end)
  end

  test "generates with `:generators` config", context do
    Application.put_env(:pow, :generators, binary_id: true, context_app: {:my_app, "my_app"})
    on_exit(fn ->
      Application.delete_env(:pow, :generators)
    end)

    file = Path.join(["my_app", "lib", "my_app", "users", "user.ex"])

    File.cd!(context.tmp_path, fn ->
      Schema.run([])

      assert File.exists?(file)
      file = File.read!(file)

      assert file =~ "@primary_key {:id, :binary_id, autogenerate: true}"
      assert file =~ "@foreign_key_type :binary_id"
    end)
  end
end
