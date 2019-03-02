defmodule PowInvitation.Ecto.SchemaTest do
  use ExUnit.Case
  doctest PowInvitation.Ecto.Schema

  alias PowInvitation.Ecto.Schema
  alias PowInvitation.Test.Users.User

  test "user_schema/1" do
    user = %User{}

    assert Map.has_key?(user, :invitation_token)
    assert Map.has_key?(user, :invitation_accepted_at)
    assert Map.has_key?(user, :invited_by)
    assert Map.has_key?(user, :invited_users)
  end

  describe "invite_changeset/3" do
    @valid_params %{email: "test@example.com"}
    @invited_by %User{id: 1}
    @invalid_params %{email: "foo"}

    test "with valid params" do
      changeset = Schema.invite_changeset(%User{}, @invited_by, @valid_params)

      assert changeset.valid?
      assert changeset.changes.email == "test@example.com"
      assert changeset.changes.invitation_token
      assert changeset.data.invited_by_id == @invited_by.id
    end

    test "with invalid params" do
      changeset = Schema.invite_changeset(%User{}, @invited_by, @invalid_params)

      refute changeset.valid?
      assert changeset.errors[:email]
    end
  end

  describe "accept_invitation_changeset/2" do
    @password "password12"
    @valid_params %{email: "test@example.com", password: @password, confirm_password: @password}
    @invalid_params %{email: "foo"}

    test "with valid params" do
      changeset = Schema.accept_invitation_changeset(%User{}, @valid_params)

      assert changeset.valid?
      assert changeset.changes.email == "test@example.com"
      assert changeset.changes.invitation_accepted_at
    end

    test "with invalid params" do
      changeset = Schema.accept_invitation_changeset(%User{}, @invalid_params)

      refute changeset.valid?
      assert changeset.errors[:email]
      assert changeset.errors[:password]
    end
  end
end
