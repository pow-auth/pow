defmodule PowEmailConfirmation.Ecto.SchemaTest do
  use ExUnit.Case
  doctest PowEmailConfirmation.Ecto.Schema

  alias Pow.Ecto.Schema.Password
  alias PowEmailConfirmation.Ecto.Schema
  alias PowEmailConfirmation.Test.{RepoMock, Users.User}

  @password          "secret1234"
  @new_user          %User{}
  @valid_new_params  %{email: "test@example.com", password: @password, confirm_password: @password}
  @edit_user         Ecto.put_meta(%User{email: "test@example.com", password_hash: Password.pbkdf2_hash(@password)}, state: :loaded)
  @valid_edit_params %{email: "test@example.com", email_confirmed_at: DateTime.utc_now(), current_password: @password}

  test "user_schema/1" do
    user = %User{}

    assert Map.has_key?(user, :email_confirmation_token)
    assert Map.has_key?(user, :email_confirmed_at)
    assert Map.has_key?(user, :unconfirmed_email)
  end

  test "changeset/2 when :built sets confirmation token" do
    changeset = User.changeset(@new_user, @valid_new_params)
    assert changeset.valid?
    assert Ecto.Changeset.get_change(changeset, :email_confirmation_token)
    refute Ecto.Changeset.get_change(changeset, :email_confirmed_at)
    refute Ecto.Changeset.get_change(changeset, :unconfirmed_email)
    refute changeset.errors[:email_confirmation_token]
  end

  test "changeset/2 when :loaded moves email change to unconfirmed_email" do
    changeset = User.changeset(@edit_user, Map.put(@valid_edit_params, :email, "new@example.com"))
    assert changeset.valid?
    refute Ecto.Changeset.get_change(changeset, :email)
    assert Ecto.Changeset.get_change(changeset, :email_confirmation_token)
    refute Ecto.Changeset.get_change(changeset, :email_confirmed_at)
    assert Ecto.Changeset.get_change(changeset, :unconfirmed_email) == "new@example.com"
    refute changeset.errors[:email_confirmation_token]
  end

  test "changeset/2 when :loaded doesn't set confirmation token when email hasn't changed" do
    changeset = User.changeset(@edit_user, Map.drop(@valid_edit_params, [:email]))
    assert changeset.valid?
    refute Ecto.Changeset.get_change(changeset, :email_confirmation_token)
    refute Ecto.Changeset.get_change(changeset, :unconfirmed_email)

    changeset = User.changeset(@edit_user, @valid_edit_params)
    assert changeset.valid?
    refute Ecto.Changeset.get_change(changeset, :email_confirmation_token)
    refute Ecto.Changeset.get_change(changeset, :unconfirmed_email)
  end

  test "changeset/2 doesn't update when has errors" do
    changeset = User.changeset(@edit_user, Map.put(@valid_edit_params, :email, "invalid"))
    refute changeset.valid?
    assert changeset.errors[:email]
    assert Ecto.Changeset.get_change(changeset, :email) == "invalid"
    refute Ecto.Changeset.get_change(changeset, :email_confirmation_token)
    refute Ecto.Changeset.get_change(changeset, :unconfirmed_email)
    refute changeset.errors[:email_confirmation_token]
    refute changeset.errors[:unconfirmed_email]
  end

  test "changeset/2 doesn't update when email already taken by another user" do
    changeset = User.changeset(@edit_user, Map.put(@valid_edit_params, :email, "taken@example.com"))
    {:error, changeset} = RepoMock.update(changeset, [])
    assert changeset.errors[:email] == {"has already been taken", [validation: :unsafe_unique, fields: [:email]]}
    assert changeset.changes.email == "taken@example.com"
    assert changeset.changes.unconfirmed_email == "taken@example.com"

    changeset = User.changeset(@edit_user, Map.put(@valid_edit_params, :email, "new@example.com"))
    {:ok, user} = RepoMock.update(changeset, [])
    assert user.email == "test@example.com"
    assert user.unconfirmed_email == "new@example.com"
  end

  test "confirm_email_changeset/1 updates :email_confirmed_at" do
    changeset = Schema.confirm_email_changeset(%{@edit_user | email_confirmed_at: nil})

    assert changeset.valid?
    refute changeset.changes[:email]
    assert changeset.changes[:email_confirmed_at]
  end

  test "confirm_email_changeset/1 puts :unconfirmed_email as :email" do
    changeset = Schema.confirm_email_changeset(%{@edit_user | email_confirmed_at: :previous, unconfirmed_email: "new@example.com"})

    assert changeset.valid?
    assert changeset.changes.email == "new@example.com"
    refute changeset.changes.unconfirmed_email
    assert changeset.changes.email_confirmed_at
  end

  test "confirm_email_changeset/1 ignores if already confirmed" do
    changeset = Schema.confirm_email_changeset(%{@edit_user | email_confirmed_at: DateTime.utc_now()})

    assert changeset.valid?
    assert changeset.changes == %{}
  end
end
