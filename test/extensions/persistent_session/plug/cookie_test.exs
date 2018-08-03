defmodule PowPersistentSession.Plug.CookieTest do
  use ExUnit.Case
  doctest PowPersistentSession.Plug.Cookie

  alias PowPersistentSession.{Plug.Cookie, Store.PersistentSessionCache}
  alias Pow.{Plug, Plug.Session}
  alias PowPersistentSession.Test.Users.User
  alias Pow.Test.{ConnHelpers, EtsCacheMock}

  @max_age Integer.floor_div(:timer.hours(24) * 30, 1000)

  setup do
    EtsCacheMock.init()
    conn =
      :get
      |> ConnHelpers.conn("/")
      |> ConnHelpers.init_session()
      |> Session.call([otp_app: PowPersistentSession.TestWeb])

    {:ok, %{conn: conn}}
  end

  defp store_persistent(conn, id, user) do
    PersistentSessionCache.put([backend: EtsCacheMock], id, user.id)
    persistent_cookie(conn, id)
  end

  defp persistent_cookie(conn, id) do
    cookies = %{"persistent_session_cookie" => id}
    %{conn | req_cookies: cookies, cookies: cookies}
  end

  test "call/2 sets pow_persistent_session_mod in conn", %{conn: conn} do
    conn = Cookie.call(conn, Cookie.init([]))

    assert {Cookie, [mod: Session, otp_app: PowPersistentSession.TestWeb]} = conn.private[:pow_persistent_session]
    refute conn.resp_cookies["persistent_session_cookie"]
  end

  test "call/2 assigns user from cookie", %{conn: conn} do
    user = %User{id: 1}
    id   = "test"
    conn =
      conn
      |> store_persistent(id, user)
      |> Cookie.call(Cookie.init([]))

    assert Plug.current_user(conn) == user
    assert %{value: new_id, max_age: @max_age, path: "/"} = conn.resp_cookies["persistent_session_cookie"]
    refute new_id == id
    assert PersistentSessionCache.get([backend: EtsCacheMock], id) == :not_found
    assert PersistentSessionCache.get([backend: EtsCacheMock], new_id) == 1
  end

  test "call/2 when user already assigned", %{conn: conn} do
    user = %User{id: 1}
    id   = "test"
    conn =
      conn
      |> store_persistent(id, user)
      |> Plug.assign_current_user(:user, [])
      |> Cookie.call(Cookie.init([]))

    assert %{value: new_id, max_age: @max_age, path: "/"} = conn.resp_cookies["persistent_session_cookie"]
    assert new_id == id
    assert PersistentSessionCache.get([backend: EtsCacheMock], id) == 1
  end

  test "call/2 when user doesn't exist in database", %{conn: conn} do
    user = %User{id: -1}
    id   = "test"
    conn =
      conn
      |> store_persistent(id, user)
      |> Cookie.call(Cookie.init([]))

    refute Plug.current_user(conn)
    assert conn.resp_cookies["persistent_session_cookie"] == %{max_age: -1, path: "/", value: ""}
    assert PersistentSessionCache.get([backend: EtsCacheMock], id) == :not_found
  end

  test "call/2 when persistent session cache doesn't have credentials", %{conn: conn} do
    conn =
      conn
      |> persistent_cookie("test")
      |> Cookie.call(Cookie.init([]))

    refute Plug.current_user(conn)
    assert conn.resp_cookies["persistent_session_cookie"] == %{max_age: -1, path: "/", value: ""}
  end
end
