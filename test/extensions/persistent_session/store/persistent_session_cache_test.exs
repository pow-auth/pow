defmodule PowPersistentSession.Store.PersistentSessionCacheTest do
  use ExUnit.Case
  doctest PowPersistentSession.Store.PersistentSessionCache

  alias ExUnit.CaptureIO
  alias PowPersistentSession.Store.PersistentSessionCache
  alias Pow.Test.Ecto.Users.User
  alias Pow.Test.EtsCacheMock

  defmodule ContextMock do
    def get_by([id: :missing]), do: nil
    def get_by([id: id]), do: %User{id: {:loaded, id}}
  end

  @config [backend: EtsCacheMock, pow_config: [users_context: ContextMock]]
  @backend_config [namespace: "persistent_session"]

  setup do
    EtsCacheMock.init()

    {:ok, ets: EtsCacheMock}
  end

  test "stores persistent sessions", %{ets: ets} do
    user_1 = %User{id: 1}
    user_2 = %User{id: 2}

    PersistentSessionCache.put(@config, "key_1", {user_1, a: 1})
    PersistentSessionCache.put(@config, "key_2", {user_1, a: 2})
    PersistentSessionCache.put(@config, "key_3", {user_2, a: 3})
    PersistentSessionCache.put(@config, "key_4", {%User{id: :missing}, a: 4})

    assert PersistentSessionCache.get(@config, "key_1") == {%User{id: {:loaded, 1}}, a: 1}
    assert PersistentSessionCache.get(@config, "key_2") == {%User{id: {:loaded, 1}}, a: 2}
    assert PersistentSessionCache.get(@config, "key_3") == {%User{id: {:loaded, 2}}, a: 3}
    refute PersistentSessionCache.get(@config, "key_4")

    assert PersistentSessionCache.delete(@config, "key_1") == :ok
    assert PersistentSessionCache.get(@config, "key_1") == :not_found
    assert ets.get(@backend_config, "key_1") == :not_found
  end

  test "get/2 when user doesn't exist" do
    PersistentSessionCache.put(@config, "token", {%User{id: :missing}, []})

    refute PersistentSessionCache.get(@config, "token")
  end

  # TODO: Remove by 1.1.0
  test "get/2 is backwards-compatible with user fetch clause", %{ets: ets} do
    ets.put(@backend_config, {"token", {[id: 1], [a: 1]}})
    assert PersistentSessionCache.get(@config, "token") == {%User{id: {:loaded, 1}}, [a: 1]}

    ets.put(@backend_config, {"token", {[id: :missing], [a: 1]}})
    refute PersistentSessionCache.get(@config, "token")
  end

  # TODO: Remove by 1.1.0
  test "get/2 is backwards-compatible with just user fetch clause", %{ets: ets} do
    ets.put(@backend_config, {"token", id: 1})

    assert PersistentSessionCache.get(@config, "token") == {%User{id: {:loaded, 1}}, []}
  end

  # TODO: Remove by 1.1.0
  test "get/2 is backwards-compatible with missing `:pow_config` in second argument" do
    user_1 = %User{id: 1}
    store_config = Keyword.delete(@config, :pow_config)
    PersistentSessionCache.put(store_config, "token", {user_1, a: 1})

    assert CaptureIO.capture_io(:stderr, fn ->
      assert PersistentSessionCache.get(Keyword.delete(@config, :pow_config), "token") == {user_1, a: 1}
    end) =~ "PowPersistentSession.Store.PersistentSessionCache.get/2 call without `:pow_config` in second argument is deprecated, find the migration step in the changelog."
  end
end
