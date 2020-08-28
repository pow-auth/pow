defmodule PowPersistentSession.Plug.CookieTest do
  use ExUnit.Case
  doctest PowPersistentSession.Plug.Cookie

  alias Plug.{Conn, ProcessStore, Test}
  alias Plug.Session, as: PlugSession
  alias Pow.{Plug, Plug.Session}
  alias PowPersistentSession.{Plug.Cookie, Store.PersistentSessionCache}
  alias PowPersistentSession.Test.Users.User
  alias Pow.Test.EtsCacheMock

  @cookie_key "persistent_session"
  @max_age Integer.floor_div(:timer.hours(24) * 30, 1000)
  @custom_cookie_opts [domain: "domain.com", max_age: 1, path: "/path", http_only: false, secure: true, extra: "SameSite=Lax"]

  setup do
    EtsCacheMock.init()

    config = PowPersistentSession.Test.pow_config()
    conn   = conn_with_session_plug(config)

    {:ok, conn: conn, config: config, ets: EtsCacheMock}
  end

  test "call/2 sets pow_persistent_session plug in conn", %{conn: conn, config: config} do
    conn            = run_plug(conn)
    expected_config = [mod: Session, plug: Session] ++ config

    assert {Cookie, ^expected_config} = conn.private[:pow_persistent_session]
    refute conn.resp_cookies[@cookie_key]
  end

  test "call/2 assigns user from cookie", %{conn: conn, ets: ets} do
    user = %User{id: 1}
    id   = store_in_cache(conn, "test", {[id: user.id], []}, backend: ets)
    conn =
      conn
      |> persistent_cookie(@cookie_key, id)
      |> run_plug()

    assert Plug.current_user(conn) == user
    assert %{value: new_id, max_age: @max_age, path: "/"} = conn.resp_cookies[@cookie_key]
    refute new_id == id
    assert get_from_cache(conn, id, backend: ets) == :not_found
    assert get_from_cache(conn, new_id, backend: ets) == {[id: 1], []}
  end

  defmodule PersistentSessionCacheWaitDelete do
    alias PowPersistentSession.Store.PersistentSessionCache

    @timeout :timer.seconds(5)

    defdelegate put(config, session_id, record_or_records), to: PersistentSessionCache

    defdelegate get(config, session_id), to: PersistentSessionCache

    def delete(config, session_id)do
      send(self(), {__MODULE__, :wait})

      receive do
        {__MODULE__, :commit} -> :ok
      after
        @timeout -> raise "Timeout reached"
      end

      PersistentSessionCache.delete(config, session_id)
    end
  end

  test "call/2 assigns user from cookie and doesn't expire with simultanous request", %{conn: conn, ets: ets} do
    :ets.delete(EtsCacheMock)
    :ets.new(EtsCacheMock, [:ordered_set, :public, :named_table])

    user   = %User{id: 1}
    id     = store_in_cache(conn, "test", {[id: user.id], []}, backend: ets)
    conn   = persistent_cookie(conn, @cookie_key, id)
    config = [persistent_session_store: {PersistentSessionCacheWaitDelete, ttl: :timer.hours(24) * 30, namespace: "persistent_session"}]

    task_1 =
      fn -> run_plug(conn, config) end
      |> Task.async()
      |> wait_till_ready()

    conn_2 =
      fn -> run_plug(conn, config) end
      |> Task.async()
      |> continue_work()
      |> Task.await()

    conn_1 =
      task_1
      |> continue_work()
      |> Task.await()

    assert Plug.current_user(conn_1) == user
    assert %{value: _id, max_age: @max_age, path: "/"} = conn_1.resp_cookies[@cookie_key]

    assert Plug.current_user(conn_2) == user
    refute conn_2.resp_cookies[@cookie_key]
  end

  defp wait_till_ready(%{pid: tracking_pid} = task) do
    :erlang.trace(tracking_pid, true, [:receive])
    assert_receive {:trace, ^tracking_pid, :receive, {PersistentSessionCacheWaitDelete, :wait}}

    task
  end

  defp continue_work(%{pid: tracking_pid} = task) do
    send(tracking_pid, {PersistentSessionCacheWaitDelete, :commit})

    task
  end

  test "call/2 assigns user from cookie passing fingerprint to the session metadata", %{conn: conn, ets: ets} do
    user = %User{id: 1}
    id   = store_in_cache(conn, "test", {[id: user.id], session_metadata: [fingerprint: "fingerprint"]}, backend: ets)
    conn =
      conn
      |> persistent_cookie(@cookie_key, id)
      |> run_plug()

    assert Plug.current_user(conn) == user
    assert %{value: new_id, max_age: @max_age, path: "/"} = conn.resp_cookies[@cookie_key]
    refute new_id == id
    assert get_from_cache(conn, id, backend: ets) == :not_found
    assert get_from_cache(conn, new_id, backend: ets) == {[id: 1], session_metadata: [fingerprint: "fingerprint"]}
    assert conn.private[:pow_session_metadata][:fingerprint] == "fingerprint"
  end

  test "call/2 assigns user from cookie passing custom metadata to session metadata", %{conn: conn, ets: ets} do
    user = %User{id: 1}
    id   = store_in_cache(conn, "test", {[id: user.id], session_metadata: [a: 1, b: 2, fingerprint: "fingerprint"]}, backend: ets)
    conn =
      conn
      |> persistent_cookie(@cookie_key, id)
      |> Conn.put_private(:pow_persistent_session_metadata, session_metadata: [a: 2])
      |> Conn.put_private(:pow_session_metadata, [a: 3, fingerprint: "new_fingerprint"])
      |> run_plug()

    assert Plug.current_user(conn) == user
    assert %{value: id, max_age: @max_age, path: "/"} = conn.resp_cookies[@cookie_key]
    assert get_from_cache(conn, id, backend: ets) == {[id: 1], session_metadata: [fingerprint: "new_fingerprint", b: 2, a: 2]}
    assert [inserted_at: _, b: 2, a: 3, fingerprint: "new_fingerprint"] = conn.private[:pow_session_metadata]
  end

  test "call/2 assigns user from cookie with prepended `:otp_app`", %{config: config, ets: ets} do
    user = %User{id: 1}
    conn = conn_with_session_plug(config ++ [otp_app: :test_app])
    id   = store_in_cache(conn, "test_app_test", {[id: user.id], []}, backend: ets)
    conn =
      conn
      |> persistent_cookie("test_app_" <> @cookie_key, id)
      |> run_plug(config)

    assert Plug.current_user(conn) == user
    assert %{value: new_id, max_age: @max_age, path: "/"} = conn.resp_cookies["test_app_" <> @cookie_key]
    assert {:ok, decoded_id} = Plug.verify_token(conn, Atom.to_string(Cookie), new_id)
    assert String.starts_with?(decoded_id, "test_app")
    assert get_from_cache(conn, new_id, backend: ets) == {[id: 1], []}
  end

  test "call/2 when user already assigned", %{conn: conn, ets: ets} do
    user = %User{id: 1}
    id   = store_in_cache(conn, "test", {[id: user.id], []}, backend: ets)
    conn =
      conn
      |> persistent_cookie(@cookie_key, id)
      |> Plug.assign_current_user(:user, [])
      |> run_plug()

    refute conn.resp_cookies[@cookie_key]
    assert get_from_cache(conn, id, backend: ets) == {[id: 1], []}
  end

  test "call/2 when user doesn't exist in database", %{conn: conn, ets: ets} do
    user = %User{id: -1}
    id   = store_in_cache(conn, "test", {[id: user.id], []}, backend: ets)
    conn =
      conn
      |> persistent_cookie(@cookie_key, id)
      |> run_plug()

    refute Plug.current_user(conn)
    refute conn.resp_cookies[@cookie_key]
    assert get_from_cache(conn, id, backend: ets) == :not_found
  end

  test "call/2 with unsigned token", %{conn: conn, ets: ets} do
    user = %User{id: 1}
    id = "test"
    store_in_cache(conn, id, {[id: user.id], []}, backend: ets)
    conn =
      conn
      |> persistent_cookie(@cookie_key, id)
      |> run_plug()

    refute Plug.current_user(conn)
    refute conn.resp_cookies[@cookie_key]
    assert PersistentSessionCache.get([backend: ets], id) == {[id: user.id], []}
  end

  test "call/2 when persistent session cache doesn't have credentials", %{conn: conn} do
    conn =
      conn
      |> persistent_cookie(@cookie_key, "test")
      |> run_plug()

    refute Plug.current_user(conn)
    refute conn.resp_cookies[@cookie_key]
  end

  test "call/2 with invalid stored clauses", %{conn: conn, ets: ets} do
    user = %User{id: 1}
    id   = store_in_cache(conn, "test", {[id: user.id, uid: 2], []}, backend: ets)

    assert_raise RuntimeError, "Invalid get_by clauses stored: [id: 1, uid: 2]", fn ->
      conn
      |> persistent_cookie(@cookie_key, id)
      |> run_plug()
    end
  end

  # TODO: Remove by 1.1.0
  test "call/2 is backwards-compatible with just user fetch clause", %{conn: conn, ets: ets} do
    user = %User{id: 1}
    id   = store_in_cache(conn, "test", [id: user.id], backend: ets)
    conn =
      conn
      |> persistent_cookie(@cookie_key, id)
      |> run_plug()

    assert Plug.current_user(conn) == user
    assert %{value: new_id, max_age: @max_age, path: "/"} = conn.resp_cookies[@cookie_key]
    refute new_id == id
    assert get_from_cache(conn, id, backend: ets) == :not_found
    assert get_from_cache(conn, new_id, backend: ets) == {[id: 1], []}
  end

  # TODO: Remove by 1.1.0
  test "call/2 is backwards-compatible with `:session_fingerprint` metadata", %{conn: conn, ets: ets} do
    user = %User{id: 1}
    id   = store_in_cache(conn, "test", {[id: user.id], session_fingerprint: "fingerprint"}, backend: ets)
    conn =
      conn
      |> persistent_cookie(@cookie_key, id)
      |> run_plug()

    assert Plug.current_user(conn) == user
    assert %{value: new_id, max_age: @max_age, path: "/"} = conn.resp_cookies[@cookie_key]
    refute new_id == id
    assert get_from_cache(conn, id, backend: ets) == :not_found
    assert get_from_cache(conn, new_id, backend: ets) == {[id: 1], session_metadata: [fingerprint: "fingerprint"]}
    assert conn.private[:pow_session_metadata][:fingerprint] == "fingerprint"
  end

  test "create/3 with custom TTL", %{conn: conn, config: config} do
    config = Keyword.put(config, :persistent_session_ttl, 1000)
    conn   =
      conn
      |> init_plug(config)
      |> run_create(%User{id: 1}, config)

    assert_received {:ets, :put, [{_key, _value} | _rest], config}
    assert config[:ttl] == 1000

    assert %{max_age: 1, path: "/"} = conn.resp_cookies[@cookie_key]
  end

  test "create/3 handles clause error", %{conn: conn, config: config} do
    assert_raise RuntimeError, "Primary key value for key `:id` in #{inspect User} can't be `nil`", fn ->
      conn
      |> init_plug(config)
      |> run_create(%User{id: nil}, config)
    end
  end

  test "create/3 with custom cookie options", %{conn: conn, config: config} do
    config = Keyword.put(config, :persistent_session_cookie_opts, @custom_cookie_opts)
    conn   =
      conn
      |> init_plug(config)
      |> run_create(%User{id: 1}, config)

    assert %{
      domain: "domain.com",
      extra: "SameSite=Lax",
      http_only: false,
      max_age: 1,
      path: "/path",
      secure: true
    } = conn.resp_cookies[@cookie_key]
  end

  test "create/3 deletes previous persistent session", %{conn: conn, config: config, ets: ets} do
    id   = store_in_cache(conn, "previous_persistent_session", {[id: 1], []}, backend: ets)
    conn = persistent_cookie(conn, @cookie_key, id)

    assert get_from_cache(conn, id, backend: ets) == {[id: 1], []}

    conn
    |> init_plug(config)
    |> run_create(%User{id: 1}, config)

    assert_received {:ets, :put, [{_key, {[id: 1], []}}], _config}
    assert get_from_cache(conn, id, backend: ets) == :not_found
  end

  test "create/3 with `[:pow_session_metadata][:fingerprint]` defined in conn.private", %{conn: conn, config: config} do
    conn
    |> Conn.put_private(:pow_session_metadata, fingerprint: "fingerprint")
    |> init_plug(config)
    |> run_create(%User{id: 1}, config)

    assert_received {:ets, :put, [{_key, {[id: 1], session_metadata: [fingerprint: "fingerprint"]}}], _config}
  end

  test "create/3 with custom metadata", %{conn: conn, config: config} do
    conn
    |> Conn.put_private(:pow_persistent_session_metadata, session_metadata: [a: 1])
    |> init_plug(config)
    |> run_create(%User{id: 1}, config)

    assert_received {:ets, :put, [{_key, {[id: 1], session_metadata: [a: 1]}}], _config}
  end

  test "delete/3", %{conn: conn, ets: ets, config: config} do
    id   = store_in_cache(conn, "test", {[id: 1], []}, backend: ets)
    conn =
      conn
      |> persistent_cookie(@cookie_key, id)
      |> init_plug(config)
      |> run_delete(config)

    assert conn.resp_cookies[@cookie_key] == %{max_age: 0, path: "/", universal_time: {{1970, 1, 1}, {0, 0, 0}}}
    assert get_from_cache(conn, id, backend: ets) == :not_found
  end

  test "delete/3 with custom cookie options", %{conn: conn, ets: ets, config: config} do
    id     = store_in_cache(conn, "test", {[id: 1], []}, backend: ets)
    config = Keyword.put(config, :persistent_session_cookie_opts, @custom_cookie_opts)
    conn   =
      conn
      |> persistent_cookie(@cookie_key, id)
      |> init_plug(config)
      |> run_delete(config)

    assert conn.resp_cookies[@cookie_key] == %{max_age: 0, universal_time: {{1970, 1, 1}, {0, 0, 0}}, path: "/path", domain: "domain.com", extra: "SameSite=Lax", http_only: false, secure: true}
    assert get_from_cache(conn, id, backend: ets) == :not_found
  end

  describe "with telemetry logging" do
    setup do
      pid    = self()
      events = [
        [:pow_persistent_session, :plug, :cookie, :create],
        [:pow_persistent_session, :plug, :cookie, :delete]
      ]

      :telemetry.attach_many("event-handler-#{inspect pid}", events, fn event, measurements, metadata, send_to: pid ->
        send(pid, {:event, event, measurements, metadata})
      end, send_to: pid)
    end

    test "logs create and delete", %{conn: conn, config: config} do
      user = %User{id: 1}

      conn =
        conn
        |> init_plug(config)
        |> Session.do_create(user, config)
        |> run_create(user, config)

      assert_receive {:event, [:pow_persistent_session, :plug, :cookie, :create], _measurements, metadata}
      assert metadata[:conn]
      assert metadata[:user] == user
      assert metadata[:session_fingerprint]

      conn
      |> recycle_session_conn(config)
      |> init_plug(config)
      |> run_delete(config)

      assert_receive {:event, [:pow_persistent_session, :plug, :cookie, :delete], _measurements, metadata}
      assert metadata[:conn]
      assert metadata[:user] == user
      assert metadata[:session_fingerprint]
    end
  end

  defp conn_with_session_plug(config, conn \\ nil) do
    conn
    |> Kernel.||(Test.conn(:get, "/"))
    |> PlugSession.call(PlugSession.init(store: ProcessStore, key: "foobar"))
    |> Session.call(Session.init(config))
  end

  defp recycle_session_conn(old_conn, config) do
    conn =
      :get
      |> Test.conn("/")
      |> Test.recycle_cookies(old_conn)

    conn_with_session_plug(config, conn)
  end

  defp persistent_cookie(conn, cookie_key, id) do
    cookies = Map.new([{cookie_key, id}])
    %{conn | cookies: cookies}
  end

  defp run_plug(conn, config \\ []) do
    conn
    |> init_plug(config)
    |> Conn.send_resp(200, "")
  end

  defp init_plug(conn, config) do
    Cookie.call(conn, Cookie.init(config))
  end

  defp run_create(conn, user, config) do
    conn
    |> Cookie.create(user, config)
    |> Conn.send_resp(200, "")
  end

  defp run_delete(conn, config) do
    conn
    |> Cookie.delete(config)
    |> Conn.send_resp(200, "")
  end

  defp store_in_cache(conn, token, value, config) do
    PersistentSessionCache.put(config, token, value)

    Plug.sign_token(conn, Atom.to_string(Cookie), token)
  end

  defp get_from_cache(conn, token, config) do
    assert {:ok, token} = Plug.verify_token(conn, Atom.to_string(Cookie), token)

    PersistentSessionCache.get(config, token)
  end
end
