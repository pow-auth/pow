defmodule PowEmailConfirmation.Ecto.ContextTest do
  use Pow.Test.Ecto.TestCase
  doctest PowEmailConfirmation.Ecto.Context

  alias Ecto.Changeset
  alias PowEmailConfirmation.Ecto.{Context, Schema}
  alias PowEmailConfirmation.Test.{RepoMock, Users.User}

  @config [repo: RepoMock, user: User]
  @user   %User{id: 1, email: "test@example.com"}

  defmodule CustomUsers do
    def get_by([email_confirmation_token: :test]), do: %User{email: :ok}
  end

  describe "get_by_confirmation_token/2" do
    test "with `:users_context`" do
      assert %User{email: :ok} = Context.get_by_confirmation_token(:test, @config ++ [users_context: CustomUsers])
    end
  end

  @valid_params %{}

  describe "confirm_email/2" do
    test "confirms with no :unconfirmed_email" do
      assert {:ok, user} = Context.confirm_email(@user, @valid_params, @config)
      assert user.email_confirmed_at
      assert user.email == "test@example.com"
    end

    test "doesn't confirm when previously confirmed" do
      previously_confirmed_at = DateTime.from_iso8601("2018-01-01 00:00:00")
      user                    = %{@user | email_confirmed_at: previously_confirmed_at}

      assert {:ok, user} = Context.confirm_email(user, @valid_params, @config)
      assert user.email_confirmed_at == previously_confirmed_at
    end

    test "changes :email to :unconfirmed_email" do
      user = %{@user | unconfirmed_email: "new@example.com"}

      assert {:ok, user} = Context.confirm_email(user, @valid_params, @config)
      assert user.email == "new@example.com"
      refute user.unconfirmed_email
    end

    test "handles unique constraint" do
      user = %{@user | unconfirmed_email: "taken@example.com"}

      assert {:error, changeset} = Context.confirm_email(user, @valid_params, @config)
      assert changeset.errors[:email] == {"has already been taken", constraint: :unique, constraint_name: "users_email_index"}
    end
  end

  @valid_params %{email: "test@example.com", password: "secret1234", password_confirmation: "secret1234"}

  test "current_email_unconfirmed?/2" do
    new_user =
      %User{}
      |> User.changeset(@valid_params)
      |> Changeset.apply_changes()

    assert Context.current_email_unconfirmed?(new_user, @config)

    updated_user =
      new_user
      |> Schema.confirm_email_changeset(%{})
      |> Changeset.apply_changes()
      |> Ecto.put_meta(state: :loaded)

    refute Context.current_email_unconfirmed?(updated_user, @config)

    updated_user =
      updated_user
      |> User.changeset(%{email: "updated@example.com", current_password: "secret1234"})
      |> Changeset.apply_changes()

    refute Context.current_email_unconfirmed?(updated_user, @config)
  end

  test "pending_email_change?/2" do
    new_user =
      %User{}
      |> User.changeset(@valid_params)
      |> Changeset.apply_changes()

    refute Context.pending_email_change?(new_user, @config)

    updated_user =
      new_user
      |> Schema.confirm_email_changeset(%{})
      |> Changeset.apply_changes()
      |> Ecto.put_meta(state: :loaded)

    refute Context.pending_email_change?(updated_user, @config)

    updated_user =
      updated_user
      |> User.changeset(%{email: "updated@example.com", current_password: "secret1234"})
      |> Changeset.apply_changes()

    assert Context.pending_email_change?(updated_user, @config)
  end
end
