defmodule PowResetPassword.Ecto.ContextTest do
  use Pow.Test.Ecto.TestCase
  doctest PowResetPassword.Ecto.Context

  alias Pow.Ecto.Schema.Password
  alias PowResetPassword.Ecto.Context
  alias PowResetPassword.Test.{RepoMock, Users.User}

  @config [repo: RepoMock, user: User]
  @password "secret1234"
  @user %User{id: 1, password_hash: :set}

  defmodule CustomUsers do
    def get_by([email: :test]), do: %User{email: :ok}
  end

  describe "get_by_email/2" do
    test "email is case insensitive when it's the user id field" do
      assert Context.get_by_email("test@example.com", @config)
      assert Context.get_by_email("TEST@EXAMPLE.COM", @config)
    end

    test "email is trimmed when it's the user id field" do
      assert Context.get_by_email(" test@example.com ", @config)
    end

    test "with `:users_context`" do
      assert %User{email: :ok} = Context.get_by_email(:test, @config ++ [users_context: CustomUsers])
    end
  end

  describe "update_password/2" do
    test "updates with compiled password hash functions" do
      assert {:ok, user} = Context.update_password(@user, %{password: @password, password_confirmation: @password}, @config)
      assert Password.pbkdf2_verify(@password, user.password_hash)
    end

    test "requires password input" do
      assert {:error, changeset} = Context.update_password(@user, %{}, @config)
      assert changeset.errors[:password] == {"can't be blank", [validation: :required]}

      assert {:error, changeset} = Context.update_password(@user, %{password: "", password_confirmation: ""}, @config)
      assert changeset.errors[:password] == {"can't be blank", [validation: :required]}
    end
  end
end
