defmodule Pow.Phoenix.SessionControllerTest do
  use Pow.Test.Phoenix.ConnCase
  alias Pow.Plug

  describe "new/2" do
    test "already signed in", %{conn: conn} do
      conn =
        conn
        |> Plug.assign_current_user(%{id: 1}, [])
        |> get(Routes.pow_session_path(conn, :new))

      assert_authenticated_redirect(conn)
    end

    test "shows", %{conn: conn} do
      conn = get(conn, Routes.pow_session_path(conn, :new))

      assert html = html_response(conn, 200)
      assert html =~ Routes.pow_session_path(conn, :create)
      refute html =~ "request_path="
      assert html =~ "<label for=\"user_email\">Email</label>"
      assert html =~ "<input id=\"user_email\" name=\"user[email]\" type=\"text\">"
      assert html =~ "<label for=\"user_password\">Password</label>"
      assert html =~ "<input id=\"user_password\" name=\"user[password]\" type=\"password\">"
      assert html =~ "<a href=\"/registration/new\">Register</a>"
    end

    test "with request_path", %{conn: conn} do
      conn = get(conn, Routes.pow_session_path(conn, :new, request_path: "/example"))

      assert html = html_response(conn, 200)
      assert html =~ Routes.pow_session_path(conn, :create, request_path: "/example")
    end
  end

  describe "create/2" do
    @valid_params %{"user" => %{"email" => "test@example.com", "password" => "secret"}}
    @invalid_params %{"user" => %{"email" => "test@example.com", "password" => "invalid"}}

    test "already signed in", %{conn: conn} do
      conn =
        conn
        |> Plug.assign_current_user(%{id: 1}, [])
        |> post(Routes.pow_session_path(conn, :create, @valid_params))

      assert_authenticated_redirect(conn)
    end

    test "with valid params", %{conn: conn} do
      conn = post conn, Routes.pow_session_path(conn, :create, @valid_params)
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) == "signed_in"
      assert %{id: 1} = Plug.current_user(conn)
      assert conn.private[:plug_session]["auth"]
    end

    test "with invalid params", %{conn: conn} do
      conn = post conn, Routes.pow_session_path(conn, :create, @invalid_params)
      assert html = html_response(conn, 200)
      assert get_flash(conn, :error) == "The provided login details did not work. Please verify your credentials, and try again."
      assert html =~ "<input id=\"user_email\" name=\"user[email]\" type=\"text\" value=\"test@example.com\">"
      assert html =~ "<input id=\"user_password\" name=\"user[password]\" type=\"password\">"
      refute Plug.current_user(conn)
      refute conn.private[:plug_session]["auth"]
      refute html =~ "request_path"
    end

    test "with valid params and request_path", %{conn: conn} do
      conn = post conn, Routes.pow_session_path(conn, :create, Map.put(@valid_params, "request_path", "/custom-url"))
      assert redirected_to(conn) == "/custom-url"
      assert get_flash(conn, :info) == "signed_in"
      assert %{id: 1} = Plug.current_user(conn)
      assert conn.private[:plug_session]["auth"]
    end

    test "with invalid params and request_path", %{conn: conn} do
      conn = post conn, Routes.pow_session_path(conn, :create, Map.put(@invalid_params, "request_path", "/custom-url"))
      assert html = html_response(conn, 200)
      assert get_flash(conn, :error) == "The provided login details did not work. Please verify your credentials, and try again."
      assert html =~ "?request_path=%2Fcustom-url"
    end
  end

  describe "delete/2" do
    test "not signed in", %{conn: conn} do
      conn = delete(conn, Routes.pow_session_path(conn, :delete))

      assert_not_authenticated_redirect(conn)
    end

    test "removes authenticated", %{conn: conn} do
      conn = post conn, Routes.pow_session_path(conn, :create, @valid_params)
      assert %{id: 1} = Plug.current_user(conn)
      assert conn.private[:plug_session]["auth"]
      :timer.sleep(10)

      conn = delete(conn, Routes.pow_session_path(conn, :delete))
      assert redirected_to(conn) == Routes.pow_session_path(conn, :new)
      assert get_flash(conn, :info) == "signed_out"
      refute Plug.current_user(conn)
      refute conn.private[:plug_session]["auth"]
    end
  end
end
