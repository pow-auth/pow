defmodule Pow.Ecto.Schema.ChangesetTest do
  use Pow.Test.Ecto.TestCase
  doctest Pow.Ecto.Schema.Changeset

  alias Pow.Ecto.Schema.{Changeset, Password}
  alias Pow.Test.Ecto.{Repo, Users.User, Users.UsernameUser}

  describe "User.changeset/2" do
    @valid_params %{
      "email" => "john.doe@example.com",
      "password" => "secret1234",
      "password_confirmation" => "secret1234",
      "custom" => "custom"
    }
    @valid_params_username %{
      "username" => "john.doe",
      "password" => "secret1234",
      "password_confirmation" => "secret1234"
    }

    test "requires user id" do
      changeset = User.changeset(%User{}, @valid_params)
      assert changeset.valid?

      changeset = User.changeset(%User{}, Map.delete(@valid_params, "email"))
      refute changeset.valid?
      assert changeset.errors[:email] == {"can't be blank", [validation: :required]}

      changeset = User.changeset(%User{email: "john.doe@example.com"}, %{email: nil})
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
      assert changeset.errors[:email] == {"has invalid format", [validation: :email_format, reason: "invalid format"]}
      assert changeset.validations[:email] == {:email_format, &Pow.Ecto.Schema.Changeset.validate_email/1}

      changeset = User.changeset(%User{}, @valid_params)
      assert changeset.valid?
    end

    test "can validate with custom e-mail validator" do
      config    = [email_validator: &{:error, "custom message #{&1}"}]
      changeset = Changeset.user_id_field_changeset(%User{}, @valid_params, config)

      refute changeset.valid?
      assert changeset.errors[:email] == {"has invalid format", [validation: :email_format, reason: "custom message john.doe@example.com"]}
      assert changeset.validations[:email] == {:email_format, config[:email_validator]}

      config    = [email_validator: fn _email -> :ok end]
      changeset = Changeset.user_id_field_changeset(%User{}, @valid_params, config)

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

    test "trims value for user id" do
      changeset = User.changeset(%User{}, Map.put(@valid_params, "email", " test@example.com "))
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :email) == "test@example.com"

      changeset = UsernameUser.changeset(%UsernameUser{}, Map.put(@valid_params, "username", " username "))
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
      assert changeset.errors[:email] == {"has already been taken", constraint: :unique, constraint_name: "users_email_index"}

      {:ok, _user} =
        %UsernameUser{}
        |> Ecto.Changeset.cast(@valid_params_username, [:username])
        |> Repo.insert()

      assert {:error, changeset} =
        %UsernameUser{}
        |> UsernameUser.changeset(@valid_params_username)
        |> Repo.insert()
      assert changeset.errors[:username] == {"has already been taken", constraint: :unique, constraint_name: "users_username_index"}
    end

    test "requires password when password_hash is nil" do
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
      changeset = User.changeset(%User{}, Map.put(@valid_params, "password", Enum.join(1..7)))

      refute changeset.valid?
      assert changeset.errors[:password] == {"should be at least %{count} character(s)", [count: 8, validation: :length, kind: :min, type: :string]}

      changeset = User.changeset(%User{}, Map.put(@valid_params, "password", Enum.join(1..4096)))
      refute changeset.valid?
      assert changeset.errors[:password] == {"should be at most %{count} character(s)", [count: 4096, validation: :length, kind: :max, type: :string]}
    end

    test "can use custom length requirements for password" do
      config = [password_min_length: 5, password_max_length: 10]

      changeset = Changeset.password_changeset(%User{}, %{"password" => "abcd"}, config)
      refute changeset.valid?
      assert changeset.errors[:password] == {"should be at least %{count} character(s)", [count: 5, validation: :length, kind: :min, type: :string]}

      changeset = Changeset.password_changeset(%User{}, %{"password" => "abcdefghijk"}, config)
      refute changeset.valid?
      assert changeset.errors[:password] == {"should be at most %{count} character(s)", [count: 10, validation: :length, kind: :max, type: :string]}
    end

    test "can confirm and hash password" do
      changeset = User.changeset(%User{}, Map.put(@valid_params, "password_confirmation", "invalid"))

      refute changeset.valid?
      assert changeset.errors[:password_confirmation] == {"does not match confirmation", [validation: :confirmation]}
      refute changeset.changes[:password_hash]

      changeset = User.changeset(%User{}, @valid_params)

      assert changeset.valid?
      assert changeset.changes[:password_hash]
      assert Password.pbkdf2_verify("secret1234", changeset.changes[:password_hash])
    end

    test "only validates password hash when no previous errors" do
      params = Map.drop(@valid_params, ["email"])
      changeset = User.changeset(%User{}, params)

      refute changeset.valid?
      refute changeset.errors[:password_hash]

      params = Map.drop(@valid_params, ["password"])
      changeset = User.changeset(%User{}, params)

      refute changeset.valid?
      refute changeset.errors[:password_hash]

      params = Map.drop(@valid_params, ["password"])
      changeset = User.changeset(%User{}, params)

      refute changeset.valid?
      refute changeset.errors[:password_hash]

      config = [password_hash_methods: {fn _ -> nil end, & &1}]
      changeset = Changeset.password_changeset(%User{}, @valid_params, config)

      refute changeset.valid?
      assert changeset.errors[:password_hash] == {"can't be blank", [validation: :required]}
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

      changeset = User.changeset(%{user | current_password: "secret1234"}, @valid_params)
      refute changeset.valid?
      assert changeset.errors[:current_password] == {"can't be blank", [validation: :required]}

      changeset = User.changeset(user, Map.put(@valid_params, "current_password", "invalid"))
      refute changeset.valid?
      assert changeset.errors[:current_password] == {"is invalid", [validation: :verify_password]}
      assert changeset.validations[:current_password] == {:verify_password, []}

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

  describe "User.verify_password/2" do
    test "verifies" do
      refute User.verify_password(%User{}, "secret1234")

      password_hash = Password.pbkdf2_hash("secret1234")
      refute User.verify_password(%User{password_hash: password_hash}, "invalid")
      assert User.verify_password(%User{password_hash: password_hash}, "secret1234")
    end

    test "prevents timing attacks" do
      config = [
        password_hash_methods: {
          fn password ->
            send(self(), {:password_hash, password})

            ""
          end,
          fn password, password_hash ->
            send(self(), {:password_verify, password, password_hash})

            false
          end
        }
      ]

      refute Changeset.verify_password(%User{password_hash: nil}, "secret1234", config)
      assert_received {:password_hash, ""}

      refute Changeset.verify_password(%User{password_hash: "hash"}, "secret1234", config)
      assert_received {:password_verify, "secret1234", "hash"}
    end
  end

  test "validate_email/1" do
    # Format
    assert Changeset.validate_email("simple@example.com") == :ok
    assert Changeset.validate_email("very.common@example.com") == :ok
    assert Changeset.validate_email("disposable.style.email.with+symbol@example.com") == :ok
    assert Changeset.validate_email("other.email-with-hyphen@example.com") == :ok
    assert Changeset.validate_email("fully-qualified-domain@example.com") == :ok
    assert Changeset.validate_email("x@example.com") == :ok
    assert Changeset.validate_email("example-indeed@strange-example.com") == :ok
    assert Changeset.validate_email("admin@mailserver1") == :ok
    assert Changeset.validate_email("example@s.example") == :ok
    assert Changeset.validate_email("\" \"@example.org") == :ok
    assert Changeset.validate_email("\"john..doe\"@example.org") == :ok

    assert Changeset.validate_email("Abc.example.com") == {:error, "invalid format"}
    assert Changeset.validate_email("A@b@c@example.com") == {:error, "invalid characters in local-part"}
    assert Changeset.validate_email("a\"b(c)d,e:f;g<h>i[j\\k]l@example.com") == {:error, "invalid characters in local-part"}
    assert Changeset.validate_email("just\"not\"right@example.com") == {:error, "invalid characters in local-part"}
    assert Changeset.validate_email("this is\"not\\allowed@example.com") == {:error, "invalid characters in local-part"}
    assert Changeset.validate_email("this\\ still\\\"not\\\\allowed@example.com") == {:error, "invalid characters in local-part"}
    assert Changeset.validate_email("1234567890123456789012345678901234567890123456789012345678901234+x@example.com") == {:error, "local-part too long"}

    # Unicode
    assert Changeset.validate_email("Pelé@example.com") == :ok
    assert Changeset.validate_email("δοκιμή@παράδειγμα.δοκιμή") == :ok
    assert Changeset.validate_email("我買@屋企.香港") == :ok
    assert Changeset.validate_email("二ノ宮@黒川.日本") == :ok
    assert Changeset.validate_email("медведь@с-балалайкой.рф") == :ok

    # All error cases
    assert Changeset.validate_email("john..doe@example.com") == {:error, "consective dots in local-part"}
    assert Changeset.validate_email("john.doe@#{String.duplicate("x", 256)}") == {:error, "domain too long"}
    assert Changeset.validate_email("john.doe@-example.com") == {:error, "domain begins with hyphen"}
    assert Changeset.validate_email("john.doe@example-") == {:error, "domain ends with hyphen"}
    assert Changeset.validate_email("john.doe@invaliddomain$") == {:error, "invalid characters in domain"}
  end
end
