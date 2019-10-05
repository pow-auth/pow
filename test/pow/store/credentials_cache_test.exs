defmodule Pow.Store.CredentialsCacheTest do
  use ExUnit.Case
  doctest Pow.Store.CredentialsCache

  alias Pow.Store.{Backend.EtsCache, CredentialsCache}
  alias Pow.Test.Ecto.Users.{User, UsernameUser}
  alias Pow.Test.EtsCacheMock

  @config [backend: EtsCacheMock]
  @backend_config [namespace: "credentials"]

  setup context do
    EtsCacheMock.init()

    {:ok, context}
  end

  test "stores sessions" do
    user_1 = %User{id: 1}
    user_2 = %User{id: 2}
    user_3 = %UsernameUser{id: 1}

    CredentialsCache.put(@config, @backend_config, "key_1", {user_1, a: 1})
    CredentialsCache.put(@config, @backend_config, "key_2", {user_1, a: 2})
    CredentialsCache.put(@config, @backend_config, "key_3", {user_2, a: 3})
    CredentialsCache.put(@config, @backend_config, "key_4", {user_3, a: 4})

    assert CredentialsCache.get(@config, @backend_config, "key_1") == {user_1, a: 1}
    assert CredentialsCache.get(@config, @backend_config, "key_2") == {user_1, a: 2}
    assert CredentialsCache.get(@config, @backend_config, "key_3") == {user_2, a: 3}
    assert CredentialsCache.get(@config, @backend_config, "key_4") == {user_3, a: 4}

    assert Enum.sort(CredentialsCache.user_session_keys(@config, @backend_config, User)) == ["pow/test/ecto/users/user_sessions_1", "pow/test/ecto/users/user_sessions_2"]
    assert CredentialsCache.user_session_keys(@config, @backend_config, UsernameUser) == ["pow/test/ecto/users/username_user_sessions_1"]

    assert CredentialsCache.sessions(@config, @backend_config, user_1) == ["key_1", "key_2"]
    assert CredentialsCache.sessions(@config, @backend_config, user_2) == ["key_3"]
    assert CredentialsCache.sessions(@config, @backend_config, user_3) == ["key_4"]

    assert EtsCacheMock.get(@backend_config, "key_1") == {"#{Macro.underscore(User)}_sessions_1", a: 1}
    assert EtsCacheMock.get(@backend_config, "#{Macro.underscore(User)}_sessions_1") == %{user: user_1, sessions: ["key_1", "key_2"]}

    CredentialsCache.put(@config, @backend_config, "key_2", {%{user_1 | email: :updated}, a: 5})
    assert CredentialsCache.get(@config, @backend_config, "key_1") == {%{user_1 | email: :updated}, a: 1}

    CredentialsCache.delete(@config, @backend_config, "key_1")
    assert CredentialsCache.get(@config, @backend_config, "key_1") == :not_found
    assert CredentialsCache.sessions(@config, @backend_config, user_1) == ["key_2"]

    CredentialsCache.delete(@config, @backend_config, "key_2")
    assert CredentialsCache.sessions(@config, @backend_config, user_1) == []

    assert EtsCacheMock.get(@backend_config, "#{Macro.underscore(User)}_sessions_1") == :not_found
  end

  test "raises for nil primary key value" do
    user_1 = %User{id: nil}

    assert_raise RuntimeError, "Primary key value for key `:id` in Pow.Test.Ecto.Users.User can't be `nil`", fn ->
      CredentialsCache.put(@config, @backend_config, "key_1", {user_1, a: 1})
    end
  end

  defmodule NoPrimaryFieldUser do
    use Ecto.Schema

    @primary_key false
    schema "users" do
      timestamps()
    end
  end

  defmodule CompositePrimaryFieldsUser do
    use Ecto.Schema

    @primary_key false
    schema "users" do
      field :some_id, :integer, primary_key: true
      field :another_id, :integer, primary_key: true

      timestamps()
    end
  end

  test "handles custom primary fields" do
    assert_raise RuntimeError, "No primary keys found for Pow.Store.CredentialsCacheTest.NoPrimaryFieldUser", fn ->
      CredentialsCache.put(@config, @backend_config, "key_1", {%NoPrimaryFieldUser{}, a: 1})
    end

    assert_raise RuntimeError, "Primary key value for key `:another_id` in Pow.Store.CredentialsCacheTest.CompositePrimaryFieldsUser can't be `nil`", fn ->
      CredentialsCache.put(@config, @backend_config, "key_1", {%CompositePrimaryFieldsUser{}, a: 1})
    end

    CredentialsCache.put(@config, @backend_config, "key_1", {%CompositePrimaryFieldsUser{some_id: 1, another_id: 2}, a: 1})

    assert CredentialsCache.user_session_keys(@config, @backend_config, CompositePrimaryFieldsUser) == ["pow/store/credentials_cache_test/composite_primary_fields_user_sessions_another_id:2_some_id:1"]
  end

  defmodule NonEctoUser do
    defstruct [:id]
  end

  test "handles non-ecto user struct" do
    assert_raise RuntimeError, "Primary key value for key `:id` in Pow.Store.CredentialsCacheTest.NonEctoUser can't be `nil`", fn ->
      CredentialsCache.put(@config, @backend_config, "key_1", {%NonEctoUser{}, a: 1})
    end

    assert CredentialsCache.put(@config, @backend_config, "key_1", {%NonEctoUser{id: 1}, a: 1})

    assert CredentialsCache.user_session_keys(@config, @backend_config, NonEctoUser) == ["pow/store/credentials_cache_test/non_ecto_user_sessions_1"]
  end

  # TODO: Remove by 1.1.0
  test "backwards compatible" do
    user_1 = %User{id: 1}
    timestamp = :os.system_time(:millisecond)

    EtsCacheMock.put(@backend_config, "key_1", {user_1, timestamp})

    assert CredentialsCache.get(@config, @backend_config, "key_1") == {user_1, timestamp}
  end

  describe "with EtsCache backend" do
    test "handles purged values" do
      user_1 = %User{id: 1}
      config = [backend: EtsCache]
      backend_config = [namespace: "credentials_cache:test"]

      CredentialsCache.put(config, backend_config ++ [ttl: 150], "key_1", {user_1, a: 1})
      :timer.sleep(50)
      CredentialsCache.put(config, backend_config ++ [ttl: 200], "key_2", {user_1, a: 2})
      :timer.sleep(50)

      assert CredentialsCache.get(config, backend_config, "key_1") == {user_1, a: 1}
      assert CredentialsCache.get(config, backend_config, "key_2") == {user_1, a: 2}
      assert CredentialsCache.sessions(config, backend_config, user_1) == ["key_1", "key_2"]

      :timer.sleep(50)
      assert CredentialsCache.get(config, backend_config, "key_1") == :not_found
      assert CredentialsCache.get(config, backend_config, "key_2") == {user_1, a: 2}
      assert CredentialsCache.sessions(config, backend_config, user_1) == ["key_1", "key_2"]

      CredentialsCache.put(config, backend_config ++ [ttl: 100], "key_2", {user_1, a: 3})
      :timer.sleep(50)
      assert CredentialsCache.sessions(config, backend_config, user_1) == ["key_2"]

      :timer.sleep(50)
      assert CredentialsCache.get(config, backend_config, "key_1") == :not_found
      assert CredentialsCache.get(config, backend_config, "key_2") == :not_found
      assert CredentialsCache.sessions(config, backend_config, user_1) == []
      assert EtsCache.get(config, "#{Macro.underscore(User)}_sessions_1") == :not_found
    end
  end
end
