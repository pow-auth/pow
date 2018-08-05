defmodule PowPersistentSession.Phoenix.ControllerCallbacksTest do
  use PowPersistentSession.TestWeb.Phoenix.ConnCase

  alias PowPersistentSession.Store.PersistentSessionCache

  @valid_params %{"email" => "test@example.com", "password" => "secret1234"}
  @max_age Integer.floor_div(:timer.hours(30) * 24, 1000)

  describe "Pow.Phoenix.SessionController.create/2" do
    test "generates cookie", %{conn: conn, ets: ets} do
      conn = post conn, Routes.pow_session_path(conn, :create, %{"user" => @valid_params})

      assert %{max_age: @max_age, path: "/", value: id} = conn.resp_cookies["persistent_session_cookie"]
      assert PersistentSessionCache.get([backend: ets], id) == 1
    end

    test "with persistent_session param set to false", %{conn: conn} do
      params = %{"user" => Map.put(@valid_params, "persistent_session", false)}
      conn   = post conn, Routes.pow_session_path(conn, :create, params)

      refute conn.resp_cookies["persistent_session_cookie"]
    end

    test "with persistent_session param set to true", %{conn: conn} do
      params = %{"user" => Map.put(@valid_params, "persistent_session", true)}
      conn   = post conn, Routes.pow_session_path(conn, :create, params)

      assert conn.resp_cookies["persistent_session_cookie"]
    end

  end

  describe "Pow.Phoenix.SessionController.delete/2" do
    test "generates cookie", %{conn: conn, ets: ets} do
      conn = post conn, Routes.pow_session_path(conn, :create, %{"user" => @valid_params})
      %{value: id} = conn.resp_cookies["persistent_session_cookie"]
      conn = delete conn, Routes.pow_session_path(conn, :delete)

      assert %{max_age: -1, path: "/", value: ""} = conn.resp_cookies["persistent_session_cookie"]
      assert PersistentSessionCache.get([backend: ets], id) == :not_found
    end
  end
end
