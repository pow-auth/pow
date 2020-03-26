defmodule Pow.Ecto.SchemaTest do
  use ExUnit.Case
  doctest Pow.Ecto.Schema

  alias Pow.Test.Ecto.Users.{User, UsernameUser}

  test "schema/2" do
    user = %User{}

    assert Map.has_key?(user, :email)
    assert Map.has_key?(user, :current_password)
    refute Map.has_key?(user, :username)

    user = %UsernameUser{}
    assert Map.has_key?(user, :username)
    refute Map.has_key?(user, :email)
  end

  test "changeset/2" do
    changeset = User.changeset(%User{}, %{custom: "custom"})
    assert changeset.changes.custom == "custom"
  end

  defmodule OverrideFieldUser do
    @moduledoc false
    use Ecto.Schema
    use Pow.Ecto.Schema

    schema "users" do
      field :password_hash, :string, source: :encrypted_password

      pow_user_fields()

      timestamps()
    end
  end

  test "schema/2 with overridden fields" do
    user = %OverrideFieldUser{}

    assert Map.has_key?(user, :password_hash)
    assert OverrideFieldUser.__schema__(:field_source, :password_hash) == :encrypted_password
  end

  defmodule OverrideAssocUser do
    @moduledoc false
    use Ecto.Schema
    use Pow.Ecto.Schema

    @pow_assocs {:has_many, :users, __MODULE__}

    @pow_assocs {:belongs_to, :parent, __MODULE__}
    @pow_assocs {:has_many, :children, __MODULE__}

    schema "users" do
      belongs_to :parent, __MODULE__, on_replace: :mark_as_invalid
      has_many :children, __MODULE__, on_delete: :delete_all

      pow_user_fields()

      timestamps()
    end
  end

  test "schema/2 with overridden assocs" do
    assert %{on_delete: :nothing} = OverrideAssocUser.__schema__(:association, :users)

    assert %{on_replace: :mark_as_invalid} = OverrideAssocUser.__schema__(:association, :parent)
    assert %{on_delete: :delete_all} = OverrideAssocUser.__schema__(:association, :children)
  end

  import ExUnit.CaptureIO

  test "warns assocs defined" do
    assert capture_io(:stderr, fn ->
      defmodule MissingAssocsUser do
        use Ecto.Schema
        use Pow.Ecto.Schema

        @pow_assocs {:belongs_to, :invited_by, __MODULE__, foreign_key: :user_id}
        @pow_assocs {:has_many, :invited, __MODULE__}

        schema "users" do
          timestamps()
        end
      end
    end) =~
      """
      Please define the following association(s) in the schema for Pow.Ecto.SchemaTest.MissingAssocsUser:

      belongs_to :invited_by, Pow.Ecto.SchemaTest.MissingAssocsUser, [foreign_key: :user_id]
      has_many :invited, Pow.Ecto.SchemaTest.MissingAssocsUser
      """
  end

  test "warns fields defined" do
    assert capture_io(:stderr, fn ->
      defmodule MissingFieldsUser do
        use Ecto.Schema
        use Pow.Ecto.Schema

        schema "users" do
          timestamps()
        end
      end
    end) =~
      """
      Please define the following field(s) in the schema for Pow.Ecto.SchemaTest.MissingFieldsUser:

      field :email, :string, [null: false]
      field :password_hash, :string
      field :current_password, :string, [virtual: true]
      field :password, :string, [virtual: true]
      """
  end
end
