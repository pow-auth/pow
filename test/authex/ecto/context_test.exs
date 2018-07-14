defmodule Authex.Ecto.ContextTest do
  use Authex.Test.Ecto.TestCase
  doctest Authex.Ecto.Context

  alias Authex.Ecto.Context
  alias Authex.Test.Ecto.{Users, Users.User, Users.UsernameUser, Repo}
  alias Ecto.Changeset

  @config [repo: Repo, user: User]
  @username_config [repo: Repo, user: UsernameUser]

  describe "authenticate/2" do
    @password "secret"
    @valid_params %{"email" => "any", "password" => @password}
    @valid_params_username %{"username" => "john.doe", "password" => @password}

    setup do
      password_hash = Comeonin.Pbkdf2.hashpwsalt(@password)
      user =
        %User{}
        |> Changeset.change(email: "any", password_hash: password_hash)
        |> Repo.insert!()
      username_user =
        %UsernameUser{}
        |> Changeset.change(username: "john.doe", password_hash: password_hash)
        |> Repo.insert!()

      {:ok, %{user: user, username_user: username_user}}
    end

    test "requires user schema mod in config" do
      assert_raise Authex.Config.ConfigError, "No :user configuration option found for user schema module.", fn ->
        Context.authenticate(Keyword.delete(@config, :user), @valid_params)
      end
    end

    test "requires repo in config" do
      assert_raise Authex.Config.ConfigError, "No :repo configuration option found for users context module.", fn ->
        Context.authenticate(Keyword.delete(@config, :repo), @valid_params)
      end
    end

    test "authenticates", %{user: user, username_user: username_user} do
      refute Context.authenticate(@config, Map.put(@valid_params, "email", "other"))
      refute Context.authenticate(@config, Map.put(@valid_params, "password", "invalid"))
      assert Context.authenticate(@config, @valid_params) == user

      refute Context.authenticate(@username_config, Map.put(@valid_params_username, "username", "jane.doe"))
      refute Context.authenticate(@username_config, Map.put(@valid_params_username, "password", "invalid"))
      assert Context.authenticate(@username_config, @valid_params_username) == username_user
    end

    test "as `use Authex.Ecto.Context`", %{user: user} do
      assert Users.authenticate(@valid_params) == user
      assert Users.authenticate(:test_macro) == :ok
    end
  end

  describe "create/2" do
    @valid_params %{
      "email" => "any",
      "custom" => "custom",
      "password" => "secret",
      "password_confirm" => "secret"
    }

    test "creates" do
      assert {:error, _changeset} = Context.create(@config, Map.delete(@valid_params, "password_confirm"))
      assert {:ok, user} = Context.create(@config, @valid_params)
      assert user.custom == "custom"
    end

    test "as `use Authex.Ecto.Context`" do
      assert {:ok, user} = Users.create(@valid_params)
      assert user.custom == "custom"

      assert Users.create(:test_macro) == :ok
    end
  end

  describe "update/2" do
    @valid_params %{
      "email" => "new",
      "custom" => "custom",
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
      assert {:error, _changeset} = Context.update(@config, user, Map.delete(@valid_params, "current_password"))
      assert {:ok, user} = Context.update(@config, user, @valid_params)
      assert Context.authenticate(@config, @valid_params).id == user.id
      assert user.custom == "custom"
    end

    test "as `use Authex.Ecto.Context`", %{user: user} do
      assert {:ok, user} = Users.update(user, @valid_params)
      assert user.custom == "custom"

      assert Users.update(user, :test_macro) == :ok
    end
  end

  describe "delete/2" do
    setup do
      changeset = Changeset.change(%User{}, email: "any")

      {:ok, %{user: Repo.insert!(changeset)}}
    end

    test "deletes", %{user: user} do
      assert {:ok, user} = Context.delete(@config, user)
      assert user.__meta__.state == :deleted
    end

    test "as `use Authex.Ecto.Context`", %{user: user} do
      assert {:ok, user} = Users.delete(user)
      assert user.__meta__.state == :deleted

      assert Users.delete(:test_macro) == :ok
    end
  end
end
