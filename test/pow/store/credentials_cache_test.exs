defmodule Pow.Store.CredentialsCacheTest do
  use ExUnit.Case
  doctest Pow.Store.CredentialsCache

  alias Pow.Store.{Backend.EtsCache, CredentialsCache}
  alias Pow.Test.Ecto.Users.{User, UsernameUser}
  alias Pow.Test.EtsCacheMock

  @config [backend: EtsCacheMock]
  @backend_config [namespace: "credentials"]

  setup do
    EtsCacheMock.init()

    {:ok, ets: EtsCacheMock}
  end

  test "stores sessions", %{ets: ets} do
    user_1 = %User{id: 1}
    user_2 = %User{id: 2}
    user_3 = %UsernameUser{id: 1}

    CredentialsCache.put(@config, "key_1", {user_1, a: 1})
    CredentialsCache.put(@config, "key_2", {user_1, a: 2})
    CredentialsCache.put(@config, "key_3", {user_2, a: 3})
    CredentialsCache.put(@config, "key_4", {user_3, a: 4})

    assert CredentialsCache.get(@config, "key_1") == {user_1, a: 1}
    assert CredentialsCache.get(@config, "key_2") == {user_1, a: 2}
    assert CredentialsCache.get(@config, "key_3") == {user_2, a: 3}
    assert CredentialsCache.get(@config, "key_4") == {user_3, a: 4}

    assert Enum.sort(CredentialsCache.users(@config, User)) == [user_1, user_2]
    assert CredentialsCache.users(@config, UsernameUser) == [user_3]

    assert CredentialsCache.sessions(@config, user_1) == ["key_1", "key_2"]
    assert CredentialsCache.sessions(@config, user_2) == ["key_3"]
    assert CredentialsCache.sessions(@config, user_3) == ["key_4"]

    assert ets.get(@backend_config, "key_1") == {[User, :user, 1], a: 1}
    assert ets.get(@backend_config, [User, :user, 1]) == user_1
    assert ets.get(@backend_config, [User, :user, 1, :session, "key_1"])

    CredentialsCache.put(@config, "key_2", {%{user_1 | email: :updated}, a: 5})
    assert CredentialsCache.get(@config, "key_1") == {%{user_1 | email: :updated}, a: 1}

    assert CredentialsCache.delete(@config, "key_1") == :ok
    assert CredentialsCache.get(@config, "key_1") == :not_found
    assert CredentialsCache.sessions(@config, user_1) == ["key_2"]

    assert ets.get(@backend_config, "key_1") == :not_found
    assert ets.get(@backend_config, [User, :user, 1]) == %{user_1 | email: :updated}
    assert ets.get(@backend_config, [User, :user, 1, :session, "key_1"]) == :not_found

    assert CredentialsCache.delete(@config, "key_2") == :ok
    assert CredentialsCache.sessions(@config, user_1) == []

    assert ets.get(@backend_config, "key_1") == :not_found
    assert ets.get(@backend_config, [User, :user, 1]) == %{user_1 | email: :updated}
    assert ets.get(@backend_config, [User, :user, 1, :session, "key_1"]) == :not_found
  end

  test "put/3 invalidates sessions with identical fingerprint" do
    user = %User{id: 1}

    CredentialsCache.put(@config, "key_1", {user, fingerprint: 1})
    CredentialsCache.put(@config, "key_2", {user, fingerprint: 2})

    assert CredentialsCache.get(@config, "key_1") == {user, fingerprint: 1}

    CredentialsCache.put(@config, "key_3", {user, fingerprint: 1})

    assert CredentialsCache.get(@config, "key_1") == :not_found
    assert CredentialsCache.get(@config, "key_2") == {user, fingerprint: 2}
    assert CredentialsCache.get(@config, "key_3") == {user, fingerprint: 1}
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

  test "sorts composite primary keys", %{ets: ets} do
    user = %CompositePrimaryFieldsUser{some_id: 1, another_id: 2}

    CredentialsCache.put(@config, "key_1", {user, a: 1})

    assert CredentialsCache.users(@config, CompositePrimaryFieldsUser) == [user]
    assert ets.get(@backend_config, [CompositePrimaryFieldsUser, :user, [another_id: 2, some_id: 1]]) == user
  end

  # TODO: Remove by 1.1.0
  test "backwards compatible", %{ets: ets} do
    user_1 = %User{id: 1}
    timestamp = :os.system_time(:millisecond)

    ets.put(@backend_config, {"key_1", {user_1, inserted_at: timestamp}})

    assert CredentialsCache.get(@config, @backend_config, "key_1") == {user_1, inserted_at: timestamp}
    assert CredentialsCache.delete(@config, @backend_config, "key_1") == :ok
    assert CredentialsCache.get(@config, @backend_config, "key_1") == :not_found

    assert CredentialsCache.user_session_keys(@config, @backend_config, User) == []

    user_2 = %UsernameUser{id: 1}

    CredentialsCache.put(@config, @backend_config, "key_1", {user_1, a: 1})
    CredentialsCache.put(@config, @backend_config, "key_2", {user_1, a: 1})
    CredentialsCache.put(@config, @backend_config, "key_3", {user_2, a: 1})

    assert CredentialsCache.user_session_keys(@config, @backend_config, User) == [[Pow.Test.Ecto.Users.User, :user, 1, :session, "key_1"], [Pow.Test.Ecto.Users.User, :user, 1, :session, "key_2"]]
    assert CredentialsCache.user_session_keys(@config, @backend_config, UsernameUser) == [[Pow.Test.Ecto.Users.UsernameUser, :user, 1, :session, "key_3"]]
  end

  describe "with EtsCache backend" do
    setup do
      start_supervised!({EtsCache, []})

      :ok
    end

    test "handles purged values" do
      user_1 = %User{id: 1}
      config = [backend: EtsCache]

      CredentialsCache.put(config ++ [ttl: 150], "key_1", {user_1, a: 1})
      :timer.sleep(50)
      CredentialsCache.put(config ++ [ttl: 200], "key_2", {user_1, a: 2})
      :timer.sleep(50)

      assert CredentialsCache.get(config, "key_1") == {user_1, a: 1}
      assert CredentialsCache.get(config, "key_2") == {user_1, a: 2}
      assert CredentialsCache.sessions(config, user_1) == ["key_1", "key_2"]

      :timer.sleep(50)
      assert CredentialsCache.get(config, "key_1") == :not_found
      assert CredentialsCache.get(config, "key_2") == {user_1, a: 2}
      assert CredentialsCache.sessions(config, user_1) == ["key_2"]

      CredentialsCache.put(config ++ [ttl: 100], "key_2", {user_1, a: 3})
      :timer.sleep(50)
      assert CredentialsCache.sessions(config, user_1) == ["key_2"]

      :timer.sleep(50)
      assert CredentialsCache.get(config, "key_1") == :not_found
      assert CredentialsCache.get(config, "key_2") == :not_found
      assert CredentialsCache.sessions(config, user_1) == []
      assert EtsCache.get(config, "#{Macro.underscore(User)}_sessions_1") == :not_found
    end
  end
end
