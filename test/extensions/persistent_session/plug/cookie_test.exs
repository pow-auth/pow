defmodule PowPersistentSession.Plug.CookieTest do
  use ExUnit.Case
  doctest PowPersistentSession.Plug.Cookie

  alias Plug.Conn
  alias Pow.{Plug, Plug.Session}
  alias Pow.Test.ConnHelpers
  alias PowPersistentSession.{Plug.Cookie, Store.PersistentSessionCache}
  alias PowPersistentSession.Test.Users.User

  @cookie_key "persistent_session"
  @max_age Integer.floor_div(:timer.hours(24) * 30, 1000)
  @custom_cookie_opts [domain: "domain.com", max_age: 1, path: "/path", http_only: false, secure: true, extra: "SameSite=Lax"]

  setup do
    config = PowPersistentSession.Test.pow_config()
    ets    = Pow.Config.get(config, :cache_store_backend, nil)

    ets.init()

    conn =
      :get
      |> ConnHelpers.conn("/")
      |> ConnHelpers.init_session()
      |> Session.call(config)

    {:ok, conn: conn, config: config, ets: ets}
  end

  test "call/2 sets pow_persistent_session plug in conn", %{conn: conn, config: config} do
    conn            = run_plug(conn)
    expected_config = [mod: Session, plug: Session] ++ config

    assert {Cookie, ^expected_config} = conn.private[:pow_persistent_session]
    refute conn.resp_cookies[@cookie_key]
  end

  test "call/2 assigns user from cookie", %{conn: conn, ets: ets} do
    user = %User{id: 1}
    id   = "test"
    conn =
      conn
      |> store_persistent(ets, id, {[id: user.id], []})
      |> run_plug()

    assert Plug.current_user(conn) == user
    assert %{value: new_id, max_age: @max_age, path: "/"} = conn.resp_cookies[@cookie_key]
    refute new_id == id
    assert PersistentSessionCache.get([backend: ets], id) == :not_found
    assert PersistentSessionCache.get([backend: ets], new_id) == {[id: 1], []}
  end

  test "call/2 assigns user from cookie and doesn't expire with simultanous request", %{conn: conn, ets: ets} do
    user = %User{id: 1}
    id   = "test"
    conn = store_persistent(conn, ets, id, {[id: user.id], []})

    first_conn = run_plug(conn)

    assert Plug.current_user(first_conn) == user
    assert %{value: _id, max_age: @max_age, path: "/"} = first_conn.resp_cookies[@cookie_key]

    second_conn = run_plug(conn)

    refute Plug.current_user(second_conn) == user
    refute second_conn.resp_cookies[@cookie_key]
  end

  test "call/2 assigns user from cookie passing fingerprint to the session metadata", %{conn: conn, ets: ets} do
    user = %User{id: 1}
    id   = "test"
    conn =
      conn
      |> store_persistent(ets, id, {[id: user.id], session_metadata: [fingerprint: "fingerprint"]})
      |> run_plug()

    assert Plug.current_user(conn) == user
    assert %{value: new_id, max_age: @max_age, path: "/"} = conn.resp_cookies[@cookie_key]
    refute new_id == id
    assert PersistentSessionCache.get([backend: ets], id) == :not_found
    assert PersistentSessionCache.get([backend: ets], new_id) == {[id: 1], session_metadata: [fingerprint: "fingerprint"]}
    assert conn.private[:pow_session_metadata][:fingerprint] == "fingerprint"
  end

  test "call/2 assigns user from cookie passing custom metadata to session metadata", %{conn: conn, ets: ets} do
    user = %User{id: 1}
    conn =
      conn
      |> store_persistent(ets, "test", {[id: user.id], session_metadata: [a: 1, b: 2, fingerprint: "fingerprint"]})
      |> Conn.put_private(:pow_persistent_session_metadata, session_metadata: [a: 2])
      |> Conn.put_private(:pow_session_metadata, [a: 3, fingerprint: "new_fingerprint"])
      |> run_plug()

    assert Plug.current_user(conn) == user
    assert %{value: id, max_age: @max_age, path: "/"} = conn.resp_cookies[@cookie_key]
    assert PersistentSessionCache.get([backend: ets], id) == {[id: 1], session_metadata: [fingerprint: "new_fingerprint", b: 2, a: 2]}
    assert [inserted_at: _, b: 2, a: 3, fingerprint: "new_fingerprint"] = conn.private[:pow_session_metadata]
  end

  test "call/2 assigns user from cookie with prepended `:otp_app`", %{config: config, ets: ets} do
    user = %User{id: 1}
    conn =
      :get
      |> ConnHelpers.conn("/")
      |> ConnHelpers.init_session()
      |> Session.call(config ++ [otp_app: :test_app])
      |> store_persistent(ets, "test_app_test", {[id: user.id], []}, "test_app_" <> @cookie_key)
      |> run_plug(config)

    assert Plug.current_user(conn) == user
    assert %{value: new_id, max_age: @max_age, path: "/"} = conn.resp_cookies["test_app_" <> @cookie_key]
    assert String.starts_with?(new_id, "test_app")
    assert PersistentSessionCache.get([backend: ets], new_id) == {[id: 1], []}
  end

  test "call/2 when user already assigned", %{conn: conn, ets: ets} do
    user = %User{id: 1}
    id   = "test"
    conn =
      conn
      |> store_persistent(ets, id, {[id: user.id], []})
      |> Plug.assign_current_user(:user, [])
      |> run_plug()

    refute conn.resp_cookies[@cookie_key]
    assert PersistentSessionCache.get([backend: ets], id) == {[id: 1], []}
  end

  test "call/2 when user doesn't exist in database", %{conn: conn, ets: ets} do
    user = %User{id: -1}
    id   = "test"
    conn =
      conn
      |> store_persistent(ets, id, {[id: user.id], []})
      |> run_plug()

    refute Plug.current_user(conn)
    refute conn.resp_cookies[@cookie_key]
    assert PersistentSessionCache.get([backend: ets], id) == :not_found
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
    id   = "test"

    assert_raise RuntimeError, "Invalid get_by clauses stored: [id: 1, uid: 2]", fn ->
      conn
      |> store_persistent(ets, id, {[id: user.id, uid: 2], []})
      |> run_plug()
    end
  end

  # TODO: Remove by 1.1.0
  test "call/2 is backwards-compatible with just user fetch clause", %{conn: conn, ets: ets} do
    user = %User{id: 1}
    id   = "test"
    conn =
      conn
      |> store_persistent(ets, id, id: user.id)
      |> run_plug()

    assert Plug.current_user(conn) == user
    assert %{value: new_id, max_age: @max_age, path: "/"} = conn.resp_cookies[@cookie_key]
    refute new_id == id
    assert PersistentSessionCache.get([backend: ets], id) == :not_found
    assert PersistentSessionCache.get([backend: ets], new_id) == {[id: 1], []}
  end

  # TODO: Remove by 1.1.0
  test "call/2 is backwards-compatible with `:session_fingerprint` metadata", %{conn: conn, ets: ets} do
    user = %User{id: 1}
    id   = "test"
    conn =
      conn
      |> store_persistent(ets, id, {[id: user.id], session_fingerprint: "fingerprint"})
      |> run_plug()

    assert Plug.current_user(conn) == user
    assert %{value: new_id, max_age: @max_age, path: "/"} = conn.resp_cookies[@cookie_key]
    refute new_id == id
    assert PersistentSessionCache.get([backend: ets], id) == :not_found
    assert PersistentSessionCache.get([backend: ets], new_id) == {[id: 1], session_metadata: [fingerprint: "fingerprint"]}
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
    conn = store_persistent(conn, ets, "previous_persistent_session", {[id: 1], []})

    assert PersistentSessionCache.get([backend: ets], "previous_persistent_session") == {[id: 1], []}

    conn
    |> init_plug(config)
    |> run_create(%User{id: 1}, config)

    assert_received {:ets, :put, [{_key, {[id: 1], []}}], _config}
    assert PersistentSessionCache.get([backend: ets], "previous_persistent_session") == :not_found
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
    id   = "test"
    conn =
      conn
      |> store_persistent(ets, id, {[id: 1], []})
      |> init_plug(config)
      |> run_delete(config)

    assert conn.resp_cookies[@cookie_key] == %{max_age: 0, path: "/", universal_time: {{1970, 1, 1}, {0, 0, 0}}}
    assert PersistentSessionCache.get([backend: ets], id) == :not_found
  end

  test "delete/3 with custom cookie options", %{conn: conn, ets: ets, config: config} do
    id   = "test"
    config = Keyword.put(config, :persistent_session_cookie_opts, @custom_cookie_opts)
    conn =
      conn
      |> store_persistent(ets, id, {[id: 1], []})
      |> init_plug(config)
      |> run_delete(config)

    assert conn.resp_cookies[@cookie_key] == %{max_age: 0, universal_time: {{1970, 1, 1}, {0, 0, 0}}, path: "/path", domain: "domain.com", extra: "SameSite=Lax", http_only: false, secure: true}
    assert PersistentSessionCache.get([backend: ets], id) == :not_found
  end

  defp store_persistent(conn, ets, id, value, cookie_key \\ @cookie_key) do
    PersistentSessionCache.put([backend: ets], id, value)
    persistent_cookie(conn, cookie_key, id)
  end

  defp persistent_cookie(conn, cookie_key, id) do
    cookies = Map.new([{cookie_key, id}])
    %{conn | req_cookies: cookies, cookies: cookies}
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
end
