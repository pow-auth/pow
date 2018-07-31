defmodule PowResetPassword.Ecto.ContextTest do
  use Pow.Test.Ecto.TestCase
  doctest PowResetPassword.Ecto.Context

  alias Pow.Ecto.Schema.Password
  alias PowResetPassword.Ecto.Context
  alias PowResetPassword.Test.{RepoMock, Users.User}

  @config [repo: RepoMock, user: User]
  @password "secret1234"
  @user %User{id: 1, password_hash: :set}

  describe "get_by_email/2" do
    test "email is case insensitive when it's the user id field" do
      assert Context.get_by_email(@config, "test@example.com")
      assert Context.get_by_email(@config, "TEST@EXAMPLE.COM")
    end
  end

  describe "update_password/2" do
    test "updates with compiled password hash methods" do
      config = @config ++ [password_hash_methods: {&(&1 <> "123"), &(&1 == &2 <> "123")}]

      assert {:ok, user} = Context.update_password(config, @user, %{password: @password, confirm_password: @password})
      assert Password.pbkdf2_verify(@password, user.password_hash)
    end

    test "requires password input" do
      assert {:error, changeset} = Context.update_password(@config, @user, %{})
      assert changeset.errors[:password] == {"can't be blank", [validation: :required]}

      assert {:error, changeset} = Context.update_password(@config, @user, %{password: "", confirm_password: ""})
      assert changeset.errors[:password] == {"can't be blank", [validation: :required]}
    end
  end
end
