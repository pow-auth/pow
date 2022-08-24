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

    alias ExUnit.CaptureIO

    # TODO: Remove by 1.1.0
    test "handle `confirm_password` conversion" do
      params =
        @valid_params
        |> Map.delete("password_confirmation")
        |> Map.put("confirm_password", "secret1234")

      assert CaptureIO.capture_io(:stderr, fn ->
        changeset = User.changeset(%User{}, params)

        assert changeset.valid?
      end) =~ "passing `confirm_password` value to `Pow.Ecto.Schema.Changeset.confirm_password_changeset/3` has been deprecated, please use `password_confirmation` instead"

      params = Map.put(params, "confirm_password", "invalid")

      assert CaptureIO.capture_io(:stderr, fn ->
        changeset = User.changeset(%User{}, params)

        refute changeset.valid?
        assert changeset.errors[:confirm_password] == {"does not match confirmation", [validation: :confirmation]}
        refute changeset.errors[:password_confirmation]
      end) =~ "passing `confirm_password` value to `Pow.Ecto.Schema.Changeset.confirm_password_changeset/3` has been deprecated, please use `password_confirmation` instead"
    end

    test "can use custom password hash functions" do
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
    # Local-part and domain from https://en.wikipedia.org/wiki/Email_address#Syntax
    assert Changeset.validate_email("John..Doe@example.com") == {:error, "consective dots in local-part"}
    assert Changeset.validate_email("\".John.Doe\"@example.com") == :ok
    assert Changeset.validate_email("\"John.Doe.\"@example.com") == :ok
    assert Changeset.validate_email("\"John..Doe\"@example.com") == :ok
    assert Changeset.validate_email("john.smith(comment)@example.com") == :ok
    assert Changeset.validate_email("(comment)john.smith@example.com") == :ok
    assert Changeset.validate_email("john.smith@(comment)example.com") == :ok
    assert Changeset.validate_email("john.smith@example.com(comment)") == :ok

    # Examples from https://en.wikipedia.org/wiki/Email_address#Examples
    assert Changeset.validate_email("simple@example.com") == :ok
    assert Changeset.validate_email("very.common@example.com") == :ok
    assert Changeset.validate_email("disposable.style.email.with+symbol@example.com") == :ok
    assert Changeset.validate_email("other.email-with-hyphen@example.com") == :ok
    assert Changeset.validate_email("fully-qualified-domain@example.com") == :ok
    assert Changeset.validate_email("user.name+tag+sorting@example.com") == :ok
    assert Changeset.validate_email("x@example.com") == :ok
    assert Changeset.validate_email("example-indeed@strange-example.com") == :ok
    assert Changeset.validate_email("admin@mailserver1") == :ok
    assert Changeset.validate_email("example@s.example") == :ok
    assert Changeset.validate_email("\" \"@example.org") == :ok
    assert Changeset.validate_email("\"john..doe\"@example.org") == :ok
    assert Changeset.validate_email("mailhost!username@example.org") == :ok
    assert Changeset.validate_email("user%example.com@example.org") == :ok

    assert Changeset.validate_email("Abc.example.com") == {:error, "invalid format"}
    assert Changeset.validate_email("A@b@c@example.com") == {:error, "invalid characters in local-part"}
    assert Changeset.validate_email("a\"b(c)d,e:f;g<h>i[j\\k]l@example.com") == {:error, "invalid characters in local-part"}
    assert Changeset.validate_email("just\"not\"right@example.com") == {:error, "invalid characters in local-part"}
    assert Changeset.validate_email("this is\"not\\allowed@example.com") == {:error, "invalid characters in local-part"}
    assert Changeset.validate_email("this\\ still\\\"not\\\\allowed@example.com") == {:error, "invalid characters in local-part"}
    assert Changeset.validate_email("1234567890123456789012345678901234567890123456789012345678901234+x@example.com") == {:error, "local-part too long"}
    assert Changeset.validate_email("i_like_underscore@but_its_not_allow_in_this_part.example.com") == {:error, "invalid characters in dns label"}

    # Unicode from https://en.wikipedia.org/wiki/Email_address#Internationalization_examples
    assert Changeset.validate_email("Pelé@example.com") == :ok
    assert Changeset.validate_email("δοκιμή@παράδειγμα.δοκιμή") == :ok
    assert Changeset.validate_email("我買@屋企.香港") == :ok
    assert Changeset.validate_email("二ノ宮@黒川.日本") == :ok
    assert Changeset.validate_email("медведь@с-балалайкой.рф") == :ok
    assert Changeset.validate_email("संपर्क@डाटामेल.भारत") == :ok

    # Test cases from https://tools.ietf.org/html/rfc3696#section-3
    # Quote issues corrected with https://www.rfc-editor.org/errata/rfc3696
    assert Changeset.validate_email("\"Abc\\@def\"@example.com") == :ok
    assert Changeset.validate_email("\"Fred\\ Bloggs\"@example.com") == :ok
    assert Changeset.validate_email("\"Joe.\\\\Blow\"@example.com") == :ok
    assert Changeset.validate_email("\"Abc@def\"@example.com") == :ok
    assert Changeset.validate_email("\"Fred Bloggs\"@example.com") == :ok
    assert Changeset.validate_email("user+mailbox@example.com") == :ok
    assert Changeset.validate_email("customer/department=shipping@example.com") == :ok
    assert Changeset.validate_email("$A12345@example.com") == :ok
    assert Changeset.validate_email("!def!xyz%abc@example.com") == :ok
    assert Changeset.validate_email("_somename@example.com") == :ok

    # IP not allowed
    refute Changeset.validate_email("jsmith@[192.168.2.1]") == :error
    refute Changeset.validate_email("jsmith@[IPv6:2001:db8::1]") == :error

    # Other successs cases
    assert Changeset.validate_email("john.doe@#{String.duplicate("x", 63)}.#{String.duplicate("x", 63)}.#{String.duplicate("x", 63)}.#{String.duplicate("x", 63)}") == :ok
    assert Changeset.validate_email("john.doe@1.2.com") == :ok
    assert Changeset.validate_email("john.doe@example.x1") == :ok
    assert Changeset.validate_email("john.doe@sub-domain-with-hyphen.domain-with-hyphen.com") == :ok

    # Other error cases
    assert Changeset.validate_email("noatsign") == {:error, "invalid format"}
    assert Changeset.validate_email("john..doe@example.com") == {:error, "consective dots in local-part"}
    assert Changeset.validate_email("john.doe@#{String.duplicate("x", 63)}.#{String.duplicate("x", 63)}.#{String.duplicate("x", 63)}.#{String.duplicate("x", 60)}.com") == {:error, "domain too long"}
    assert Changeset.validate_email("john.doe@-example.com") == {:error, "dns label begins with hyphen"}
    assert Changeset.validate_email("john.doe@-example.example.com") == {:error, "dns label begins with hyphen"}
    assert Changeset.validate_email("john.doe@example-.com") == {:error, "dns label ends with hyphen"}
    assert Changeset.validate_email("john.doe@example-.example.com") == {:error, "dns label ends with hyphen"}
    assert Changeset.validate_email("john.doe@invaliddomain$") == {:error, "invalid characters in dns label"}
    assert Changeset.validate_email("john(comment)doe@example.com") == {:error, "invalid characters in local-part"}
    assert Changeset.validate_email("johndoe@example(comment).com") == {:error, "invalid characters in dns label"}
    assert Changeset.validate_email("john.doe@.") == {:error, "dns label is too short"}
    assert Changeset.validate_email("john.doe@.com") == {:error, "dns label is too short"}
    assert Changeset.validate_email("john.doe@example.") == {:error, "dns label is too short"}
    assert Changeset.validate_email("john.doe@example.1") == {:error, "tld cannot be all-numeric"}
    assert Changeset.validate_email("john.doe@#{String.duplicate("x", 64)}.com") == {:error, "dns label too long"}
    assert Changeset.validate_email("john.doe@#{String.duplicate("x", 64)}.example.com") == {:error, "dns label too long"}
  end
end
