defmodule PowEmailConfirmation.Ecto.SchemaTest do
  use ExUnit.Case
  doctest PowEmailConfirmation.Ecto.Schema

  alias PowEmailConfirmation.Ecto.Schema
  alias PowEmailConfirmation.Test.{RepoMock, Users.User}

  @password     "secret1234"
  @valid_params %{email: "test@example.com", password: @password, password_confirmation: @password, current_password: @password}

  defmodule OverridenChangesetUser do
    @moduledoc false
    use Ecto.Schema
    use Pow.Ecto.Schema
    use Pow.Extension.Ecto.Schema,
      extensions: [PowEmailConfirmation]

    @ecto_derive_inspect_for_redacted_fields false

    schema "users" do
      pow_user_fields()

      timestamps()
    end

    def confirm_email_changeset(user_or_changeset, params) do
      user_or_changeset
      |> pow_current_password_changeset(params)
      |> pow_confirm_email_changeset(params)
    end
  end

  test "user_schema/1" do
    user = %User{}

    assert Map.has_key?(user, :email_confirmation_token)
    assert Map.has_key?(user, :email_confirmed_at)
    assert Map.has_key?(user, :unconfirmed_email)
  end

  test "changeset/2 with new user struct sets :email_confirmation_token and doesn't set :unconfirmed_email" do
    changeset = User.changeset(%User{}, @valid_params)

    assert changeset.valid?
    assert Ecto.Changeset.get_change(changeset, :email) == "test@example.com"
    assert Ecto.Changeset.get_change(changeset, :email_confirmation_token)
    refute Ecto.Changeset.get_change(changeset, :unconfirmed_email)
    refute Ecto.Changeset.get_change(changeset, :email_confirmed_at)
  end

  describe "changeset/2 with persisted user struct" do
    setup do
      {:ok, user} =
        %User{}
        |> User.changeset(@valid_params)
        |> RepoMock.insert([])

      {:ok, user: user}
    end

    test "moves :email to :unconfirmed_email", %{user: user} do
      changeset = User.changeset(user, Map.put(@valid_params, :email, "new@example.com"))

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :email) == "test@example.com"
      assert Ecto.Changeset.get_change(changeset, :email_confirmation_token)
      assert Ecto.Changeset.get_change(changeset, :unconfirmed_email) == "new@example.com"
      refute Ecto.Changeset.get_change(changeset, :email_confirmed_at)
    end

    test "when :email not submitted doesn't set :email_confirmation_token and :unconfirmed_email", %{user: user} do
      changeset = User.changeset(user, Map.drop(@valid_params, [:email]))

      assert changeset.valid?
      refute Ecto.Changeset.get_change(changeset, :email_confirmation_token)
      refute Ecto.Changeset.get_change(changeset, :unconfirmed_email)
    end

    test "when :email reverted resets :confirmation_token and :unconfirmed_email", %{user: user} do
      {:ok, user} =
        user
        |> User.changeset(Map.put(@valid_params, :email, "new@example.com"))
        |> RepoMock.update([])

      assert user.unconfirmed_email == "new@example.com"
      assert user.email_confirmation_token
      assert user.email == "test@example.com"

      {:ok, user} =
        user
        |> User.changeset(Map.put(@valid_params, :email, "test@example.com"))
        |> RepoMock.update([])

      refute user.unconfirmed_email
      refute user.email_confirmation_token
      assert user.email == "test@example.com"
    end

    test "doesn't update :email_confirmation_token when :email already set as :unconfirmed_email", %{user: user} do
      params = Map.put(@valid_params, :email, "new@example.com")

      {:ok, user} =
        user
        |> User.changeset(params)
        |> RepoMock.update([])

      changeset = User.changeset(user, params)

      assert changeset.valid?
      refute Ecto.Changeset.get_change(changeset, :email)
      refute Ecto.Changeset.get_change(changeset, :unconfirmed_email)
      refute Ecto.Changeset.get_change(changeset, :email_confirmation_token)
    end

    test "doesn't update when has errors", %{user: user} do
      changeset = User.changeset(user, Map.put(@valid_params, :email, "invalid"))

      refute changeset.valid?
      assert changeset.errors[:email] == {"has invalid format", [validation: :email_format, reason: "invalid format"]}
      assert changeset.validations[:email] == {:email_format, &Pow.Ecto.Schema.Changeset.validate_email/1}
      refute Ecto.Changeset.get_change(changeset, :email_confirmation_token)
      refute Ecto.Changeset.get_change(changeset, :unconfirmed_email)

      {:ok, user} =
        user
        |> User.changeset(Map.put(@valid_params, :email, "new@example.com"))
        |> RepoMock.update([])

      changeset = User.changeset(user, Map.put(@valid_params, :email, "invalid"))

      refute changeset.valid?
      assert changeset.errors[:email] == {"has invalid format", [validation: :email_format, reason: "invalid format"]}
      assert changeset.validations[:email] == {:email_format, &Pow.Ecto.Schema.Changeset.validate_email/1}
      assert Ecto.Changeset.get_field(changeset, :email_confirmation_token) == user.email_confirmation_token
      assert Ecto.Changeset.get_field(changeset, :unconfirmed_email) == user.unconfirmed_email
    end
  end

  describe "confirm_email_changeset/1" do
    setup do
      {:ok, user} =
        %User{}
        |> User.changeset(@valid_params)
        |> RepoMock.insert([])

      {:ok, user: user}
    end

    test "updates :email_confirmed_at", %{user: user} do
      changeset = Schema.confirm_email_changeset(user, %{})

      assert changeset.valid?
      assert changeset.changes.email_confirmed_at
    end

    test "moves :unconfirmed_email to :email", %{user: user} do
      {:ok, user} =
        user
        |> User.changeset(Map.put(@valid_params, :email, "new@example.com"))
        |> RepoMock.update([])

      refute user.email_confirmed_at
      assert user.unconfirmed_email
      assert user.email_confirmation_token

      {:ok, user} =
        user
        |> Schema.confirm_email_changeset(%{})
        |> RepoMock.update([])

      assert user.email_confirmed_at
      assert user.email == "new@example.com"
      refute user.unconfirmed_email
      refute user.email_confirmation_token
    end

    test "doesn't change if already confirmed", %{user: user} do
      {:ok, user} =
        user
        |> User.changeset(Map.put(@valid_params, :email, "new@example.com"))
        |> RepoMock.update([])

      {:ok, user} =
        user
        |> Schema.confirm_email_changeset(%{})
        |> RepoMock.update([])

      changeset = Schema.confirm_email_changeset(user, %{})

      assert changeset.valid?
      assert changeset.changes == %{}
    end

    test "with overridden changeset" do
      {:ok, user} =
        %OverridenChangesetUser{}
        |> OverridenChangesetUser.changeset(@valid_params)
        |> RepoMock.insert([])

      changeset = OverridenChangesetUser.confirm_email_changeset(user, %{})

      refute changeset.valid?

      changeset = OverridenChangesetUser.confirm_email_changeset(user, %{"current_password" => @password})

      assert changeset.valid?
    end
  end
end
