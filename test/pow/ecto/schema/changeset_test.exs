defmodule Pow.Ecto.Schema.ChangesetTest do
  use Pow.Test.Ecto.TestCase
  doctest Pow.Ecto.Schema.Changeset

  alias Pow.Ecto.Schema.{Changeset, Password}
  alias Pow.Test.Ecto.{Repo, Users.User, Users.UsernameUser}

  describe "User.changeset/2" do
    @valid_params %{
      "email" => "john.doe@example.com",
      "password" => "secret1234",
      "confirm_password" => "secret1234",
      "custom" => "custom"
    }
    @valid_params_username %{
      "username" => "john.doe",
      "password" => "secret1234",
      "confirm_password" => "secret1234"
    }

    test "requires user id" do
      changeset = User.changeset(%User{}, @valid_params)
      assert changeset.valid?

      changeset = User.changeset(%User{}, Map.delete(@valid_params, "email"))
      refute changeset.valid?
      assert changeset.errors[:email] == {"can't be blank", [validation: :required]}

      changeset = UsernameUser.changeset(%UsernameUser{}, Map.delete(@valid_params_username, "username"))
      refute changeset.valid?
      assert changeset.errors[:username] == {"can't be blank", [validation: :required]}

      changeset = UsernameUser.changeset(%UsernameUser{}, @valid_params_username)
      assert changeset.valid?
    end

    test "validates user id as email" do
      changeset = User.changeset(%User{}, Map.put(@valid_params, "email", "invalid"))
      refute changeset.valid?
      assert changeset.errors[:email] == {"has invalid format", [validation: :format]}

      changeset = User.changeset(%User{}, Map.put(@valid_params, "email", ".wooly@example.com"))
      refute changeset.valid?
      assert changeset.errors[:email] == {"has invalid format", [validation: :format]}

      changeset = User.changeset(%User{}, @valid_params)
      assert changeset.valid?
    end

    test "uses case insensitive value for user id" do
      changeset = User.changeset(%User{}, Map.put(@valid_params, "email", "Test@EXAMPLE.com"))
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :email) == "test@example.com"

      changeset = UsernameUser.changeset(%UsernameUser{}, Map.put(@valid_params, "username", "uSerName"))
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :username) == "username"
    end

    test "requires unique user id" do
      {:ok, _user} =
        %User{}
        |> Ecto.Changeset.cast(@valid_params, [:email])
        |> Repo.insert()

      assert {:error, changeset} =
        %User{}
        |> User.changeset(@valid_params)
        |> Repo.insert()
      assert changeset.errors[:email] == {"has already been taken", [constraint: :unique, constraint_name: "users_email_index"]}

      {:ok, _user} =
        %UsernameUser{}
        |> Ecto.Changeset.cast(@valid_params_username, [:username])
        |> Repo.insert()

      assert {:error, changeset} =
        %UsernameUser{}
        |> UsernameUser.changeset(@valid_params_username)
        |> Repo.insert()
      assert changeset.errors[:username] == {"has already been taken", [constraint: :unique, constraint_name: "users_username_index"]}
    end

    test "requires password when no password_hash is nil" do
      params = Map.delete(@valid_params, "password")
      changeset = User.changeset(%User{}, params)

      refute changeset.valid?
      assert changeset.errors[:password] == {"can't be blank", [validation: :required]}

      password = "secret"
      user = %User{password_hash: Password.pbkdf2_hash(password)}
      params = Map.put(@valid_params, "current_password", password)
      changeset = User.changeset(user, params)

      assert changeset.valid?
    end

    test "validates length of password" do
      changeset = User.changeset(%User{}, Map.put(@valid_params, "password", Enum.join(1..9)))

      refute changeset.valid?
      assert changeset.errors[:password] == {"should be at least %{count} character(s)", [count: 10, validation: :length, kind: :min]}

      changeset = User.changeset(%User{}, Map.put(@valid_params, "password", Enum.join(1..4096)))
      refute changeset.valid?
      assert changeset.errors[:password] == {"should be at most %{count} character(s)", [count: 4096, validation: :length, kind: :max]}
    end

    test "can use custom length requirements for password" do
      config = [password_min_length: 5, password_max_length: 10]

      changeset = Changeset.password_changeset(%User{}, %{"password" => "abcd"}, config)
      refute changeset.valid?
      assert changeset.errors[:password] == {"should be at least %{count} character(s)", [count: 5, validation: :length, kind: :min]}

      changeset = Changeset.password_changeset(%User{}, %{"password" => "abcdefghijk"}, config)
      refute changeset.valid?
      assert changeset.errors[:password] == {"should be at most %{count} character(s)", [count: 10, validation: :length, kind: :max]}
    end

    test "can confirm and hash password" do
      changeset = User.changeset(%User{}, Map.put(@valid_params, "confirm_password", "invalid"))

      refute changeset.valid?
      assert changeset.errors[:confirm_password] == {"not same as password", []}
      refute changeset.changes[:password_hash]

      changeset = User.changeset(%User{}, @valid_params)

      assert changeset.valid?
      assert changeset.changes[:password_hash]
      assert Password.pbkdf2_verify("secret1234", changeset.changes[:password_hash])
    end

    test "can use custom password hash methods" do
      password_hash = &(&1 <> "123")
      password_verify = &(&1 == &2 <> "123")
      config = [password_hash_methods: {password_hash, password_verify}]

      changeset = Changeset.password_changeset(%User{}, @valid_params, config)

      assert changeset.valid?
      assert changeset.changes[:password_hash] == "secret1234123"
    end

    test "requires current password when password_hash exists" do
      user = %User{password_hash: Password.pbkdf2_hash("secret1234")}

      changeset = User.changeset(%User{}, @valid_params)
      assert changeset.valid?

      changeset = User.changeset(user, @valid_params)
      refute changeset.valid?
      assert changeset.errors[:current_password] == {"can't be blank", [validation: :required]}

      changeset = User.changeset(user, Map.put(@valid_params, "current_password", "invalid"))
      refute changeset.valid?
      assert changeset.errors[:current_password] == {"is invalid", []}

      changeset = User.changeset(user, Map.put(@valid_params, "current_password", "secret1234"))
      assert changeset.valid?
    end

    test "as `use User`" do
      changeset = User.changeset(%User{}, @valid_params)
      assert changeset.valid?
      assert changeset.changes[:email]
      assert changeset.changes[:custom]
    end
  end

  test "User.verify_password/2" do
    refute User.verify_password(%User{}, "secret1234")

    password_hash = Password.pbkdf2_hash("secret1234")
    refute User.verify_password(%User{password_hash: password_hash}, "invalid")
    assert User.verify_password(%User{password_hash: password_hash}, "secret1234")
  end
end
