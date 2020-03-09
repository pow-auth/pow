defmodule PowResetPassword.Ecto.SchemaTest do
  use ExUnit.Case
  doctest PowResetPassword.Ecto.Schema

  alias PowResetPassword.Ecto.Schema
  alias PowResetPassword.Test.Users.User

  defmodule OverridenMethodUser do
    @moduledoc false
    use Ecto.Schema
    use Pow.Ecto.Schema
    use Pow.Extension.Ecto.Schema,
      extensions: [PowResetPassword]

    schema "users" do
      field :password_reset_at, :utc_datetime

      pow_user_fields()

      timestamps()
    end

    def reset_password_changeset(user_or_changeset, params) do
      user_or_changeset
      |> pow_reset_password_changeset(params)
      |> Ecto.Changeset.put_change(:password_reset_at, DateTime.utc_now())
    end
  end

  describe "reset_password_changeset/2" do
    @valid_params %{password: "password", password_confirmation: "password"}

    test "with valid params" do
      changeset = Schema.reset_password_changeset(%User{}, @valid_params)

      assert changeset.valid?
      assert changeset.changes.password_hash
    end

    test "with overridden method" do
      changeset = OverridenMethodUser.reset_password_changeset(%OverridenMethodUser{}, @valid_params)

      assert changeset.valid?
      assert changeset.changes.password_reset_at
    end
  end
end
