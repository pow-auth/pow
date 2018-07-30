defmodule PowResetPassword.Ecto.ContextTest do
  use Pow.Test.Ecto.TestCase
  doctest PowResetPassword.Ecto.Context

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
    test "updates" do
      assert {:ok, _user} = Context.update_password(@config, @user, %{password: @password, confirm_password: @password})
    end

    test "requires password input" do
      assert {:error, changeset} = Context.update_password(@config, @user, %{})
      assert changeset.errors[:password] == {"can't be blank", [validation: :required]}

      assert {:error, changeset} = Context.update_password(@config, @user, %{password: "", confirm_password: ""})
      assert changeset.errors[:password] == {"can't be blank", [validation: :required]}
    end
  end
end
