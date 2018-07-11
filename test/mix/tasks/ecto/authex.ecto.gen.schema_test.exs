defmodule Mix.Tasks.Authex.Ecto.Gen.SchemaTest do
  use ExUnit.Case

  alias Mix.Tasks.Authex.Ecto.Gen.Schema

  @tmp_path "tmp/#{inspect(Schema)}"
  @options  ["--no-migrations"]

  setup do
    File.rm_rf!(@tmp_path)
    File.mkdir_p!(@tmp_path)
    File.cd!(@tmp_path)

    :ok
  end

  test "generates schema file" do
    Schema.run(@options)

    path = Path.join(["lib", "authex", "users"])
    file = "user.ex"

    assert File.ls!(path) == [file]

    content = File.read!(Path.join(path, file))

    assert content =~ "defmodule Authex.Users.User do"
  end

  test "doesn't make duplicate files" do
    Schema.run(@options)

    assert_raise Mix.Error, "schema file can't be created, there is already a schema file in lib/authex/users/user.ex.", fn ->
      Schema.run(@options)
    end
  end
end
