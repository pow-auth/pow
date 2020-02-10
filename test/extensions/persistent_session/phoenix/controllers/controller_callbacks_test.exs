defmodule PowPersistentSession.Phoenix.ControllerCallbacksTest do
  use PowPersistentSession.TestWeb.Phoenix.ConnCase

  alias Pow.Plug
  alias PowPersistentSession.{Plug.Cookie, Store.PersistentSessionCache}

  @valid_params %{"email" => "test@example.com", "password" => "secret1234"}
  @max_age Integer.floor_div(:timer.hours(30) * 24, 1000)
  @cookie_key "persistent_session"

  describe "Pow.Phoenix.SessionController.create/2" do
    test "generates cookie", %{conn: conn, ets: ets} do
      conn = post conn, Routes.pow_session_path(conn, :create, %{"user" => @valid_params})

      assert session_fingerprint = conn.private[:pow_session_metadata][:fingerprint]
      assert %{max_age: @max_age, path: "/", value: id} = conn.resp_cookies[@cookie_key]
      assert get_from_cache(conn, id, backend: ets) == {[id: 1], session_metadata: [fingerprint: session_fingerprint]}
    end

    test "with persistent_session param set to false", %{conn: conn} do
      params = %{"user" => Map.put(@valid_params, "persistent_session", false)}
      conn   = post conn, Routes.pow_session_path(conn, :create, params)

      refute conn.resp_cookies[@cookie_key]
    end

    test "with persistent_session param set to true", %{conn: conn} do
      params = %{"user" => Map.put(@valid_params, "persistent_session", true)}
      conn   = post conn, Routes.pow_session_path(conn, :create, params)

      assert conn.resp_cookies[@cookie_key]
    end
  end

  describe "Pow.Phoenix.SessionController.delete/2" do
    test "expires cookie", %{conn: conn, ets: ets} do
      conn = post conn, Routes.pow_session_path(conn, :create, %{"user" => @valid_params})

      assert %{value: id} = conn.resp_cookies[@cookie_key]

      conn = delete conn, Routes.pow_session_path(conn, :delete)

      assert conn.resp_cookies[@cookie_key] == %{max_age: 0, path: "/", universal_time: {{1970, 1, 1}, {0, 0, 0}}}
      assert get_from_cache(conn, id, backend: ets) == :not_found
    end
  end

  defp get_from_cache(conn, token, config) do
    assert {:ok, token} = Plug.verify_token(conn, Atom.to_string(Cookie), token, config)

    PersistentSessionCache.get(config, token)
  end
end
