defmodule Authex.Phoenix.SessionControllerTest do
  use Authex.Test.Phoenix.ConnCase
  alias Authex.Authorization.Plug

  describe "new/2" do
    test "shows", %{conn: conn} do
      conn = get(conn, Routes.authex_session_path(conn, :new))

      assert html = html_response(conn, 200)
      assert html =~ "New session"
    end
  end

  describe "create/2" do
    @valid_params %{"user" => %{"email" => "test@example.com", "password" => "secret"}}
    @invalid_params %{"user" => %{"email" => "test@example.com", "password" => "invalid"}}

    test "already signed in", %{conn: conn} do
      conn =
        conn
        |> Plug.assign_current_user(%{id: 1}, [])
        |> post(Routes.authex_session_path(conn, :create, @valid_params))

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) == "You're already authenticated."
    end

    test "with valid params", %{conn: conn} do
      conn = post conn, Routes.authex_session_path(conn, :create, @valid_params)
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) == "User successfully signed in."
      assert Plug.current_user(conn) == %{id: 1}
      assert conn.private[:plug_session]["auth"]
    end

    test "with invalid params", %{conn: conn} do
      conn = post conn, Routes.authex_session_path(conn, :create, @invalid_params)
      assert html = html_response(conn, 200)
      assert get_flash(conn, :error) == "Could not sign in user. Please try again."
      assert html =~ "New session"
      refute Plug.current_user(conn)
      refute conn.private[:plug_session]["auth"]
    end
  end

  describe "delete/2" do
    test "not signed in", %{conn: conn} do
      conn = delete(conn, Routes.authex_session_path(conn, :delete))

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) == "You're not authenticated."
    end

    test "removes authenticated", %{conn: conn} do
      conn = post conn, Routes.authex_session_path(conn, :create, @valid_params)
      assert Plug.current_user(conn) == %{id: 1}
      assert conn.private[:plug_session]["auth"]

      conn = delete(conn, Routes.authex_session_path(conn, :delete))
      assert redirected_to(conn) == Routes.authex_session_path(conn, :new)
      assert get_flash(conn, :info) == "Signed out successfullly."
      refute Plug.current_user(conn)
      refute conn.private[:plug_session]["auth"]
    end
  end
end
