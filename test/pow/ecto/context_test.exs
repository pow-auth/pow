defmodule Pow.Ecto.ContextTest do
  use Pow.Test.Ecto.TestCase
  doctest Pow.Ecto.Context

  alias Ecto.Changeset
  alias Pow.Ecto.Context
  alias Pow.Test.Ecto.{Repo, Users, Users.User, Users.UsernameUser}

  @config [repo: Repo, user: User]
  @username_config [repo: Repo, user: UsernameUser]

  describe "authenticate/2" do
    @password "secret1234"
    @valid_params %{"email" => "test@example.com", "password" => @password}
    @valid_params_username %{"username" => "john.doe", "password" => @password}

    setup do
      password_hash = Comeonin.Pbkdf2.hashpwsalt(@password)
      user =
        %User{}
        |> Changeset.change(email: "test@example.com", password_hash: password_hash)
        |> Repo.insert!()
      username_user =
        %UsernameUser{}
        |> Changeset.change(username: "john.doe", password_hash: password_hash)
        |> Repo.insert!()

      {:ok, %{user: user, username_user: username_user}}
    end

    test "requires user schema mod in config" do
      assert_raise Pow.Config.ConfigError, "No :user configuration option found for user schema module.", fn ->
        Context.authenticate(Keyword.delete(@config, :user), @valid_params)
      end
    end

    test "requires repo in config" do
      assert_raise Pow.Config.ConfigError, "No :repo configuration option found for users context module.", fn ->
        Context.authenticate(Keyword.delete(@config, :repo), @valid_params)
      end
    end

    test "authenticates", %{user: user, username_user: username_user} do
      refute Context.authenticate(@config, Map.put(@valid_params, "email", "other@example.com"))
      refute Context.authenticate(@config, Map.put(@valid_params, "password", "invalid"))
      assert Context.authenticate(@config, @valid_params) == user

      refute Context.authenticate(@username_config, Map.put(@valid_params_username, "username", "jane.doe"))
      refute Context.authenticate(@username_config, Map.put(@valid_params_username, "password", "invalid"))
      assert Context.authenticate(@username_config, @valid_params_username) == username_user
    end

    test "authenticates with case insensitive value for user id field", %{user: user, username_user: username_user} do
      assert Context.authenticate(@config, %{"email" => "TEST@example.COM", "password" => @password}) == user
      assert Context.authenticate(@username_config, %{"username" => "JOHN.doE", "password" => @password}) == username_user
    end

    test "as `use Pow.Ecto.Context`", %{user: user} do
      assert Users.authenticate(@valid_params) == user
      assert Users.authenticate(:test_macro) == :ok
    end
  end

  describe "create/2" do
    @valid_params %{
      "email" => "test@example.com",
      "custom" => "custom",
      "password" => @password,
      "confirm_password" => @password
    }

    test "creates" do
      assert {:error, _changeset} = Context.create(@config, Map.delete(@valid_params, "confirm_password"))
      assert {:ok, user} = Context.create(@config, @valid_params)
      assert user.custom == "custom"
      refute user.password
      refute user.confirm_password
    end

    test "as `use Pow.Ecto.Context`" do
      assert {:ok, user} = Users.create(@valid_params)
      assert user.custom == "custom"
      refute user.password

      assert Users.create(:test_macro) == :ok
    end
  end

  describe "update/2" do
    @valid_params %{
      "email" => "new@example.com",
      "custom" => "custom",
      "password" => "new_#{@password}",
      "confirm_password" => "new_#{@password}",
      "current_password" => @password
    }

    setup do
      password_hash = Comeonin.Pbkdf2.hashpwsalt(@password)
      changeset = Changeset.change(%User{}, email: "test@exampe.com", password_hash: password_hash)

      {:ok, %{user: Repo.insert!(changeset)}}
    end

    test "updates", %{user: user} do
      assert {:error, _changeset} = Context.update(@config, user, Map.delete(@valid_params, "current_password"))
      assert {:ok, updated_user} = Context.update(@config, user, @valid_params)
      assert Context.authenticate(@config, @valid_params) == updated_user
      assert updated_user.custom == "custom"
      refute updated_user.password
      refute updated_user.confirm_password
      refute updated_user.current_password
    end

    test "as `use Pow.Ecto.Context`", %{user: user} do
      assert {:ok, user} = Users.update(user, @valid_params)
      assert user.custom == "custom"
      refute user.password

      assert Users.update(user, :test_macro) == :ok
    end
  end

  describe "delete/2" do
    setup do
      changeset = Changeset.change(%User{}, email: "test@example.com")

      {:ok, %{user: Repo.insert!(changeset)}}
    end

    test "deletes", %{user: user} do
      assert {:ok, user} = Context.delete(@config, user)
      assert user.__meta__.state == :deleted
    end

    test "as `use Pow.Ecto.Context`", %{user: user} do
      assert {:ok, user} = Users.delete(user)
      assert user.__meta__.state == :deleted

      assert Users.delete(:test_macro) == :ok
    end
  end

  describe "get_by/2" do
    @email "test@example.com"
    @username "john.doe"

    setup do
      changeset = Changeset.change(%User{}, email: @email)
      changeset_username = Changeset.change(%UsernameUser{}, username: @username)

      {:ok, %{user: Repo.insert!(changeset), username_user: Repo.insert!(changeset_username)}}
    end

    test "retrieves", %{user: user, username_user: username_user} do
      get_by_user = Context.get_by(@config, email: @email)
      assert get_by_user.id == user.id

      get_by_user = Context.get_by(@username_config, username: @username)
      assert get_by_user.id == username_user.id
    end

    test "retrieves with case insensitive user id", %{user: user, username_user: username_user} do
      get_by_user = Context.get_by(@config, email: "TEST@EXAMPLE.COM")
      assert get_by_user.id == user.id

      get_by_user = Context.get_by(@username_config, username: "JOHN.DOE")
      assert get_by_user.id == username_user.id
    end

    test "as `use Pow.Ecto.Context`", %{user: user} do
      get_by_user = Users.get_by(email: @email)
      assert get_by_user.id == user.id

      assert Users.get_by(:test_macro) == :ok
    end
  end
end
