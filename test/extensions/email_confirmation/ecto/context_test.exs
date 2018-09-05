defmodule PowEmailConfirmation.Ecto.ContextTest do
  use Pow.Test.Ecto.TestCase
  doctest PowEmailConfirmation.Ecto.Context

  alias PowEmailConfirmation.Ecto.Context
  alias PowEmailConfirmation.Test.{RepoMock, Users.User}

  @config [repo: RepoMock, user: User]
  @user   %User{id: 1, email: "test@example.com"}

  describe "confirm_email/2" do
    test "confirms with no :unconfirmed_email" do
      assert {:ok, user} = Context.confirm_email(@user, @config)
      assert user.email_confirmed_at
      assert user.email == "test@example.com"
    end

    test "doesn't confirm when previously confirmed" do
      previously_confirmed_at = DateTime.from_iso8601("2018-01-01 00:00:00")
      user                    = %{@user | email_confirmed_at: previously_confirmed_at}

      assert {:ok, user} = Context.confirm_email(user, @config)
      assert user.email_confirmed_at == previously_confirmed_at
    end

    test "changes :email to :unconfirmed_email" do
      user = %{@user | unconfirmed_email: "new@example.com"}
      assert {:ok, user} = Context.confirm_email(user, @config)
      assert user.email == "new@example.com"
      refute user.unconfirmed_email
    end

    test "handles unique index" do
      user = %{@user | unconfirmed_email: "taken@example.com"}
      assert {:error, changeset} = Context.confirm_email(user, @config)
      assert changeset.errors[:email] == {"has already been taken", []}
    end
  end
end
