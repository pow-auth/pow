defmodule Authex.Ecto.UsersContextTest do
  use Authex.Test.Ecto.TestCase
  doctest Authex.Ecto.UsersContext

  alias Authex.Ecto.UsersContext
  alias Authex.Test.Ecto.{Users, Users.User, Repo}
  alias Ecto.Changeset

  @config [repo: Repo, user: User]
  @invalid_config [repo: Invalid, user: Invalid]
  @username_config Keyword.put(@config, :login_field, :username)

  describe "changeset/2" do
    @valid_params %{
      "username" => "john.doe",
      "email" => "any",
      "password" => "secret",
      "password_confirm" => "secret"
    }

    test "requires login field" do
      changeset = UsersContext.changeset(@config, @valid_params)
      assert changeset.valid?

      changeset = UsersContext.changeset(@config, Map.delete(@valid_params, "email"))
      refute changeset.valid?
      assert changeset.errors[:email] == {"can't be blank", [validation: :required]}

      changeset = UsersContext.changeset(@username_config, Map.delete(@valid_params, "username"))
      refute changeset.valid?
      assert changeset.errors[:username] == {"can't be blank", [validation: :required]}

      changeset = UsersContext.changeset(@username_config, @valid_params)
      assert changeset.valid?
    end

    test "requires unique login field" do
      {:ok, _user} = %User{} |> Changeset.cast(@valid_params, [:email, :username]) |> Repo.insert()
      valid_params = Map.merge(@valid_params, %{"email" =>"other", "username" => "jane.doe"})

      assert {:error, changeset} =
        @config
        |> UsersContext.changeset(@valid_params)
        |> Repo.insert()
      assert changeset.errors[:email] == {"has already been taken", []}

      assert {:ok, user} =
        @config
        |> UsersContext.changeset(valid_params)
        |> Repo.insert()

      {:ok, _user} = UsersContext.delete(@config, user)

      assert {:error, changeset} =
        @username_config
        |> UsersContext.changeset(@valid_params)
        |> Repo.insert()
      assert changeset.errors[:username] == {"has already been taken", []}

      assert {:ok, _user} =
        @username_config
        |> UsersContext.changeset(valid_params)
        |> Repo.insert()
    end

    test "requires password when no password_hash is nil" do
      params = Map.delete(@valid_params, "password")

      changeset = UsersContext.changeset(@config, params)
      refute changeset.valid?
      assert changeset.errors[:password] == {"can't be blank", [validation: :required]}

      user = %User{password_hash: Comeonin.Pbkdf2.hashpwsalt("secret")}
      params = Map.put(@valid_params, "current_password", "secret")

      changeset = UsersContext.changeset(user, @username_config, params)
      assert changeset.valid?
    end

    test "can confirm and hash password" do
      changeset = UsersContext.changeset(@config, Map.put(@valid_params, "password_confirm", "invalid"))

      refute changeset.valid?
      assert changeset.errors[:password_confirm] == {"not same as password", []}
      refute changeset.changes[:password_hash]

      changeset = UsersContext.changeset(@config, @valid_params)

      assert changeset.valid?
      assert changeset.changes[:password_hash]
      assert Comeonin.Pbkdf2.checkpw("secret", changeset.changes[:password_hash])
    end

    test "can use custom password hash methods" do
      password_hash = &(&1 <> "123")
      password_verify = &(&1 == &2 <> "123")
      config = Keyword.merge(@config, [password_hash_methods: {password_hash, password_verify}])

      changeset = UsersContext.changeset(config, @valid_params)

      assert changeset.valid?
      assert changeset.changes[:password_hash] == "secret123"
    end

    test "requires current password when password_hash exists" do
      user = %User{password_hash: Comeonin.Pbkdf2.hashpwsalt("secret")}

      changeset = UsersContext.changeset(@config, @valid_params)
      assert changeset.valid?

      changeset = UsersContext.changeset(user, @config, @valid_params)
      refute changeset.valid?
      assert changeset.errors[:current_password] == {"can't be blank", [validation: :required]}

      changeset = UsersContext.changeset(user, @config, Map.put(@valid_params, "current_password", "invalid"))
      refute changeset.valid?
      assert changeset.errors[:current_password] == {"is invalid", []}

      changeset = UsersContext.changeset(user, @config, Map.put(@valid_params, "current_password", "secret"))
      assert changeset.valid?
    end

    test "as `use UsersContext`" do
      changeset = Users.changeset(%User{}, [], @valid_params)
      assert changeset.valid?
      assert changeset.changes[:email]
      assert changeset.changes[:username]
    end
  end

  describe "authenticate/2" do
    @valid_params %{"email" => "any", "password" => "secret"}

    setup do
      password_hash = Comeonin.Pbkdf2.hashpwsalt("secret")
      changeset = Changeset.change(%User{}, username: "john.doe", email: "any", password_hash: password_hash)

      {:ok, %{user: Repo.insert!(changeset)}}
    end

    test "requires user schema mod in config" do
      assert_raise Authex.Config.ConfigError, "No :user configuration option found for user schema module.", fn ->
        UsersContext.authenticate(Keyword.delete(@config, :user), @valid_params)
      end
    end

    test "requires repo in config" do
      assert_raise Authex.Config.ConfigError, "No :repo configuration option found for users context module.", fn ->
        UsersContext.authenticate(Keyword.delete(@config, :repo), @valid_params)
      end
    end

    test "authenticates", %{user: user} do
      refute UsersContext.authenticate(@config, Map.put(@valid_params, "email", "other"))
      refute UsersContext.authenticate(@config, Map.put(@valid_params, "password", "invalid"))
      assert UsersContext.authenticate(@config, @valid_params) == user

      refute UsersContext.authenticate(@username_config, @valid_params)
      refute UsersContext.authenticate(@username_config, Map.put(@valid_params, "username", "jane.doe"))
      assert UsersContext.authenticate(@username_config, Map.put(@valid_params, "username", "john.doe")) == user
    end

    test "as `use UsersContext`", %{user: user} do
      assert Users.authenticate(@invalid_config, @valid_params) == user

      assert Users.authenticate([], :test_macro) == :ok
    end
  end

  describe "create/2" do
    @valid_params %{
      "email" => "any",
      "username" => "john.doe",
      "password" => "secret",
      "password_confirm" => "secret"
    }

    test "creates" do
      assert {:error, _changeset} = UsersContext.create(@config, Map.delete(@valid_params, "password_confirm"))
      assert {:ok, user} = UsersContext.create(@config, @valid_params)
      refute user.username
    end

    test "as `use UsersContext`" do
      assert {:ok, user} = Users.create(@invalid_config, @valid_params)
      assert user.username == "john.doe"
    end
  end

  describe "update/2" do
    @valid_params %{
      "email" => "new",
      "username" => "john.doe",
      "password" => "new_secret",
      "password_confirm" => "new_secret",
      "current_password" => "secret"
    }

    setup do
      password_hash = Comeonin.Pbkdf2.hashpwsalt("secret")
      changeset = Changeset.change(%User{}, email: "any", password_hash: password_hash)

      {:ok, %{user: Repo.insert!(changeset)}}
    end

    test "updates", %{user: user} do
      assert {:error, _changeset} = UsersContext.update(@config, user, Map.delete(@valid_params, "current_password"))
      assert {:ok, user} = UsersContext.update(@config, user, @valid_params)
      assert UsersContext.authenticate(@config, @valid_params).id == user.id
      refute user.username
    end

    test "as `use UsersContext`", %{user: user} do
      assert {:ok, user} = Users.update(@invalid_config, user, @valid_params)
      assert user.username == "john.doe"
    end
  end

  describe "delete/2" do
    setup do
      changeset = Changeset.change(%User{}, email: "any")

      {:ok, %{user: Repo.insert!(changeset)}}
    end

    test "deletes", %{user: user} do
      assert {:ok, user} = UsersContext.delete(@config, user)
      assert user.__meta__.state == :deleted
    end

    test "as `use UsersContext`", %{user: user} do
      assert {:ok, user} = Users.delete(@invalid_config, user)
      assert user.__meta__.state == :deleted

      assert Users.delete([], :test_macro) == :ok
    end
  end
end
