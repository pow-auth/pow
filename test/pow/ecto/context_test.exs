defmodule Pow.Ecto.ContextTest do
  use Pow.Test.Ecto.TestCase
  doctest Pow.Ecto.Context

  defmodule TimingAttackUser do
    @moduledoc false
    use Ecto.Schema
    use Pow.Ecto.Schema, password_hash_methods: {&__MODULE__.send_hash_password/1, &__MODULE__.send_verify_password/2}

    @ecto_derive_inspect_for_redacted_fields false

    alias Pow.Ecto.Schema.Password

    schema "users" do
      pow_user_fields()

      timestamps()
    end

    def send_hash_password(password) do
      send(self(), {:password_hash, password})
      Password.pbkdf2_hash(password)
    end

    def send_verify_password(password, password_hash) do
      send(self(), {:password_verify, password, password_hash})
      Password.pbkdf2_verify(password, password_hash)
    end
  end

  alias Ecto.Changeset
  alias Pow.Ecto.{Context, Schema.Password}
  alias Pow.Test.Ecto.{Repo, Users, Users.User, Users.UsernameUser}

  @config [repo: Repo, user: User]
  @username_config [repo: Repo, user: UsernameUser]

  defmodule CustomUsers do
    use Context, repo: Repo, user: User

    def get_by([email: :test]), do: %User{email: :ok, password_hash: Password.pbkdf2_hash("secret1234")}
  end

  describe "authenticate/2" do
    @password "secret1234"
    @valid_params %{"email" => "test@example.com", "password" => @password}
    @valid_params_username %{"username" => "john.doe", "password" => @password}

    setup do
      password_hash = Password.pbkdf2_hash(@password)
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
      assert_raise Pow.Config.ConfigError, "No `:user` configuration option found.", fn ->
        Context.authenticate(@valid_params, Keyword.delete(@config, :user))
      end
    end

    test "requires repo in config" do
      assert_raise Pow.Config.ConfigError, "No `:repo` configuration option found.", fn ->
        Context.authenticate(@valid_params, Keyword.delete(@config, :repo))
      end
    end

    test "authenticates", %{user: user, username_user: username_user} do
      refute Context.authenticate(Map.put(@valid_params, "email", "other@example.com"), @config)
      refute Context.authenticate(Map.put(@valid_params, "password", "invalid"), @config)
      assert Context.authenticate(@valid_params, @config) == user

      refute Context.authenticate(Map.put(@valid_params_username, "username", "jane.doe"), @username_config)
      refute Context.authenticate(Map.put(@valid_params_username, "password", "invalid"), @username_config)
      assert Context.authenticate(@valid_params_username, @username_config) == username_user
    end

    test "authenticates with case insensitive value for user id field", %{user: user, username_user: username_user} do
      assert Context.authenticate(%{"email" => "TEST@example.COM", "password" => @password}, @config) == user
      assert Context.authenticate(%{"username" => "JOHN.doE", "password" => @password}, @username_config) == username_user
    end

    test "handles nil values" do
      refute Context.authenticate(%{"password" => @password}, @config)
      refute Context.authenticate(%{"email" => nil, "password" => @password}, @config)
      refute Context.authenticate(%{"email" => "test@example.com"}, @config)
      refute Context.authenticate(%{"email" => "test@example.com", "password" => nil}, @config)
    end

    test "authenticates with extra trailing and leading whitespace for user id field", %{user: user, username_user: username_user} do
      assert Context.authenticate(%{"email" => " test@example.com ", "password" => @password}, @config) == user
      assert Context.authenticate(%{"username" => " john.doe ", "password" => @password}, @username_config) == username_user
    end

    test "as `use Pow.Ecto.Context`", %{user: user} do
      assert Users.authenticate(@valid_params) == user
      assert Users.authenticate(:test_macro) == :ok
    end

    test "with `:users_context`" do
      params = Map.put(@valid_params, "email", :test)

      assert %User{email: :ok} = Context.authenticate(params, @config ++ [users_context: CustomUsers])
      assert %User{email: :ok} = CustomUsers.authenticate(params)
    end

    test "prevents timing attack" do
      config = [repo: Repo, user: TimingAttackUser]

      refute Context.authenticate(Map.put(@valid_params, "email", "other@example.com"), config)
      assert_received {:password_hash, ""}
      refute Context.authenticate(Map.put(@valid_params, "password", "invalid"), config)
      assert_received {:password_verify, "invalid", _any}
      assert Context.authenticate(@valid_params, config)
      assert_received {:password_verify, "secret1234", _any}
    end
  end

  describe "create/2" do
    @valid_params %{
      "email" => "test@example.com",
      "custom" => "custom",
      "password" => @password,
      "password_confirmation" => @password
    }

    test "creates" do
      assert {:error, _changeset} = Context.create(Map.delete(@valid_params, "password_confirmation"), @config)
      assert {:ok, user} = Context.create(@valid_params, @config)
      assert user.custom == "custom"
      refute user.password
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
      "password_confirmation" => "new_#{@password}",
      "current_password" => @password
    }

    setup do
      password_hash = Password.pbkdf2_hash(@password)
      changeset = Changeset.change(%User{}, email: "test@exampe.com", password_hash: password_hash)

      {:ok, %{user: Repo.insert!(changeset)}}
    end

    test "updates", %{user: user} do
      assert {:error, _changeset} = Context.update(user, Map.delete(@valid_params, "current_password"), @config)
      assert {:ok, updated_user} = Context.update(user, @valid_params, @config)
      assert Context.authenticate(@valid_params, @config) == updated_user
      assert updated_user.custom == "custom"
      refute updated_user.password
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
      assert {:ok, user} = Context.delete(user, @config)
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
      get_by_user = Context.get_by([email: @email], @config)
      assert get_by_user.id == user.id

      get_by_user = Context.get_by([username: @username], @username_config)
      assert get_by_user.id == username_user.id
    end

    test "retrieves with case insensitive user id", %{user: user, username_user: username_user} do
      get_by_user = Context.get_by([email: "TEST@EXAMPLE.COM"], @config)
      assert get_by_user.id == user.id

      get_by_user = Context.get_by([username: "JOHN.DOE"], @username_config)
      assert get_by_user.id == username_user.id
    end

    test "handles nil value before normalization of user id field value" do
      assert_raise ArgumentError, ~r/Comparison with nil is forbidden as it is unsafe/, fn ->
        Context.get_by([email: nil], @config)
      end
    end

    test "as `use Pow.Ecto.Context`", %{user: user} do
      get_by_user = Users.get_by(email: @email)
      assert get_by_user.id == user.id

      assert Users.get_by(:test_macro) == :ok
    end
  end
end
