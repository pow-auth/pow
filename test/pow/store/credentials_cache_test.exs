defmodule Pow.Store.CredentialsCacheTest do
  use ExUnit.Case
  doctest Pow.Store.CredentialsCache

  alias ExUnit.CaptureIO
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

  test "when using unsafe session ttl" do
    config = @config ++ [ttl: :timer.minutes(30) + 1]

    assert CaptureIO.capture_io(:stderr, fn ->
      CredentialsCache.put(config, "key_1", {%User{id: 1}, a: 1})
    end) =~ "warning: `:ttl` value for sessions should be no longer than 30 minutes to prevent session hijack, please consider lowering the value"
  end

  test "get/2 when reload: true without :pow_config" do
    config = @config ++ [reload: true]

    CredentialsCache.put(config, "session_id", {%User{id: 1}, a: 1})

    assert_raise RuntimeError, "No `:pow_config` value found in the store config.", fn ->
      CredentialsCache.get(config, "session_id")
    end
  end

  defmodule ContextMock do
    def get_by([id: 1]), do: %User{id: :loaded}
    def get_by([id: :missing]), do: nil
  end

  test "get/2 when reload: true", %{ets: ets} do
    config = @config ++ [reload: true, pow_config: [users_context: ContextMock]]

    CredentialsCache.put(config, "session_id", {%User{id: 1}, a: 1})

    assert CredentialsCache.get(config, "session_id") == {%User{id: :loaded}, a: 1}
    refute ets.get(@backend_config, "session_id") == :not_found
  end

  test "get/2 when reload: true and user doesn't exist" do
    config = @config ++ [reload: true, pow_config: [users_context: ContextMock]]

    CredentialsCache.put(config, "session_id", {%User{id: :missing}, a: 1})

    refute CredentialsCache.get(config, "session_id")
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

    assert_capture_io_eval(quote do
      assert CredentialsCache.user_session_keys(unquote(@config), unquote(@backend_config), User) == []
    end, "Pow.Store.CredentialsCache.user_session_keys/3 is deprecated. Use `users/2` or `sessions/2` instead")

    user_2 = %UsernameUser{id: 1}

    CredentialsCache.put(@config, @backend_config, "key_1", {user_1, a: 1})
    CredentialsCache.put(@config, @backend_config, "key_2", {user_1, a: 1})
    CredentialsCache.put(@config, @backend_config, "key_3", {user_2, a: 1})

    assert_capture_io_eval(quote do
      assert CredentialsCache.user_session_keys(unquote(@config), unquote(@backend_config), User) == [[Pow.Test.Ecto.Users.User, :user, 1, :session, "key_1"], [Pow.Test.Ecto.Users.User, :user, 1, :session, "key_2"]]
      assert CredentialsCache.user_session_keys(unquote(@config), unquote(@backend_config), UsernameUser) == [[Pow.Test.Ecto.Users.UsernameUser, :user, 1, :session, "key_3"]]
    end, "Pow.Store.CredentialsCache.user_session_keys/3 is deprecated. Use `users/2` or `sessions/2` instead")
  end


  alias ExUnit.CaptureIO

  defp assert_capture_io_eval(quoted, message) do
    System.version()
    |> Version.match?(">= 1.8.0")
    |> case do
      true ->
        # Due to https://github.com/elixir-lang/elixir/pull/9626 it's necessary to
        # import `ExUnit.Assertions`
        pre_elixir_1_10_quoted =
          quote do
            import ExUnit.Assertions
          end

        assert CaptureIO.capture_io(:stderr, fn ->
          Code.eval_quoted([pre_elixir_1_10_quoted, quoted])
        end) =~ message

      false ->
        IO.warn("Please upgrade to Elixir 1.8 to captured and assert IO message: #{inspect message}")

        :ok
    end
  end

  describe "with EtsCache backend" do
    setup do
      start_supervised!({EtsCache, []})

      :ok
    end

    test "handles purged values" do
      user_1 = %User{id: 1}
      config = [backend: EtsCache]

      CredentialsCache.put(config ++ [ttl: 50], "key_1", {user_1, a: 1})
      CredentialsCache.put(config ++ [ttl: 150], "key_2", {user_1, a: 2})
      assert CredentialsCache.get(config, "key_1") == {user_1, a: 1}
      assert CredentialsCache.get(config, "key_2") == {user_1, a: 2}
      assert CredentialsCache.sessions(config, user_1) == ["key_1", "key_2"]

      :timer.sleep(100)
      assert CredentialsCache.get(config, "key_1") == :not_found
      assert CredentialsCache.get(config, "key_2") == {user_1, a: 2}
      assert CredentialsCache.sessions(config, user_1) == ["key_2"]

      CredentialsCache.put(config ++ [ttl: 150], "key_2", {user_1, a: 3})
      :timer.sleep(100)
      assert CredentialsCache.sessions(config, user_1) == ["key_2"]

      :timer.sleep(100)
      assert CredentialsCache.get(config, "key_1") == :not_found
      assert CredentialsCache.get(config, "key_2") == :not_found
      assert CredentialsCache.sessions(config, user_1) == []
      assert EtsCache.get(config, "#{Macro.underscore(User)}_sessions_1") == :not_found
    end
  end
end
