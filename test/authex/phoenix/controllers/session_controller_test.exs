defmodule Authex.Phoenix.SessionControllerTest do
  use Authex.Test.Phoenix.ConnCase
  alias Authex.Plug

  describe "new/2" do
    test "shows", %{conn: conn} do
      conn = get(conn, Routes.authex_session_path(conn, :new))

      assert html = html_response(conn, 200)
      assert html =~ "<label for=\"user_email\">Email</label>"
      assert html =~ "<input id=\"user_email\" name=\"user[email]\" type=\"text\">"
      assert html =~ "<label for=\"user_password\">Password</label>"
      assert html =~ "<input id=\"user_password\" name=\"user[password]\" type=\"password\">"
    end

    test "already signed in", %{conn: conn} do
      conn =
        conn
        |> Plug.assign_current_user(%{id: 1}, [])
        |> get(Routes.authex_session_path(conn, :new))

      assert_authenticated_redirect(conn)
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
      assert %{id: 1} = Plug.current_user(conn)
      assert conn.private[:plug_session]["auth"]
    end

    test "with invalid params", %{conn: conn} do
      conn = post conn, Routes.authex_session_path(conn, :create, @invalid_params)
      assert html = html_response(conn, 200)
      assert get_flash(conn, :error) == "Could not sign in user. Please try again."
      assert html =~ "<input id=\"user_email\" name=\"user[email]\" type=\"text\" value=\"test@example.com\">"
      assert html =~ "<input id=\"user_password\" name=\"user[password]\" type=\"password\">"
      refute Plug.current_user(conn)
      refute conn.private[:plug_session]["auth"]
    end
  end

  describe "delete/2" do
    test "not signed in", %{conn: conn} do
      conn = delete(conn, Routes.authex_session_path(conn, :delete))

      assert_not_authenticated_redirect(conn)
    end

    test "removes authenticated", %{conn: conn} do
      conn = post conn, Routes.authex_session_path(conn, :create, @valid_params)
      assert %{id: 1} = Plug.current_user(conn)
      assert conn.private[:plug_session]["auth"]
      :timer.sleep(10)

      conn = delete(conn, Routes.authex_session_path(conn, :delete))
      assert redirected_to(conn) == Routes.authex_session_path(conn, :new)
      assert get_flash(conn, :info) == "Signed out successfullly."
      refute Plug.current_user(conn)
      refute conn.private[:plug_session]["auth"]
    end
  end
end
