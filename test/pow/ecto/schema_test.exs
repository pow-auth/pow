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

    @ecto_derive_inspect_for_redacted_fields false

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

    @ecto_derive_inspect_for_redacted_fields false

    @pow_assocs {:has_many, :users, __MODULE__, []}

    @pow_assocs {:belongs_to, :parent, __MODULE__, []}
    @pow_assocs {:has_many, :children, __MODULE__, []}

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

  alias ExUnit.CaptureIO

  test "warns assocs defined" do
    assert CaptureIO.capture_io(:stderr, fn ->
      defmodule MissingAssocsUser do
        use Ecto.Schema
        use Pow.Ecto.Schema

        @pow_assocs {:belongs_to, :invited_by, __MODULE__, foreign_key: :user_id}
        @pow_assocs {:has_many, :invited, __MODULE__, []}

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
    assert CaptureIO.capture_io(:stderr, fn ->
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

      field :email, :string
      field :password_hash, :string, [redact: true]
      field :current_password, :string, [virtual: true, redact: true]
      field :password, :string, [virtual: true, redact: true]
      """
  end

  test "warns invalid fields defined" do
    assert CaptureIO.capture_io(:stderr, fn ->
      defmodule InvalidFieldUser do
        use Ecto.Schema
        use Pow.Ecto.Schema

        schema "users" do
          field :email, :utc_datetime
          field :password_hash, :string, redact: true
          field :current_password, :string, virtual: true, redact: true
          field :password, :string, virtual: true, redact: true

          timestamps()
        end
      end
    end) =~
      """
      Please define the following field(s) in the schema for Pow.Ecto.SchemaTest.InvalidFieldUser:

      field :email, :string
      """
  end

  test "doesn't warn for field with custom type" do
    assert CaptureIO.capture_io(:stderr, fn ->
      defmodule CustomType do
        use Ecto.Type

        def type, do: :binary

        def cast(value), do: {:ok, value}

        def load(value), do: {:ok, value}

        def dump(value), do: {:ok, value}
      end

      defmodule CustomFieldTypeUser do
        use Ecto.Schema
        use Pow.Ecto.Schema

        @ecto_derive_inspect_for_redacted_fields false

        schema "users" do
          field :email, CustomType
          field :password_hash, :string, redact: true
          field :current_password, :string, virtual: true, redact: true
          field :password, :string, virtual: true, redact: true

          timestamps()
        end
      end
    end) == ""
  end

  test "raises with invalid field defined" do
    assert_raise RuntimeError, "`@pow_fields` is required to have the format `{name, type, defaults}`.\n\nThe value provided was: :invalid\n", fn ->
      defmodule InvalidPowFieldsUser do
        use Ecto.Schema
        use Pow.Ecto.Schema

        @pow_fields :invalid

        schema "users" do
          timestamps()
        end
      end
    end
  end

  test "raises with invalid assocs defined" do
    assert_raise RuntimeError, "`@pow_assocs` is required to have the format `{type, field, module, defaults}`.\n\nThe value provided was: {:belongs_to, :invited_by, Test}\n", fn ->
      defmodule InvalidPowAssocsUser do
        use Ecto.Schema
        use Pow.Ecto.Schema

        @pow_assocs {:belongs_to, :invited_by, Test}

        schema "users" do
          timestamps()
        end
      end
    end
  end
end
