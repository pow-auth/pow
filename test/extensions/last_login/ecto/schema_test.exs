defmodule PowLastLogin.Ecto.SchemaTest do
  use ExUnit.Case
  doctest PowLastLogin.Ecto.Schema

  alias PowLastLogin.Ecto.Schema
  alias PowLastLogin.Test.{Users.User}

  @password      "secret1234"
  @user          Ecto.put_meta(%User{email: "test@example.com", password: @password, confirm_password: @password}, state: :loaded)

  @first_login_at    DateTime.utc_now()
  @first_login_from  "127.0.0.1"
  @second_login_from "127.0.0.2"

  test "user_schema/1" do
    user = %User{}

    assert Map.has_key?(user, :current_login_at)
    assert Map.has_key?(user, :current_login_from)
    assert Map.has_key?(user, :last_login_at)
    assert Map.has_key?(user, :last_login_from)
  end

  test "last_login_changeset/2 sets :current_login_from and :current_login_at" do
    changeset = Schema.last_login_changeset(@user, @first_login_from)
    assert changeset.valid?

    assert changeset.changes.current_login_from == @first_login_from
    assert Ecto.Changeset.get_change(changeset, :current_login_at)
    refute Ecto.Changeset.get_change(changeset, :last_login_at)
    refute Ecto.Changeset.get_change(changeset, :last_login_from)
    refute changeset.errors[:current_login_at]
    refute changeset.errors[:current_login_from]
    refute changeset.errors[:last_login_at]
    refute changeset.errors[:last_login_from]
  end

  test "last_login_changeset/2 puts :current_login_at as :last_login_at and :current_login_from as :last_login_from" do
    user = %{@user | current_login_at: @first_login_at, current_login_from: @first_login_from}

    changeset = Schema.last_login_changeset(user, @second_login_from)
    assert changeset.valid?

    refute changeset.changes.current_login_at == user.current_login_at
    assert changeset.changes.current_login_from == @second_login_from
    assert changeset.changes.last_login_at == @first_login_at
    assert changeset.changes.last_login_from == @first_login_from
  end
end
