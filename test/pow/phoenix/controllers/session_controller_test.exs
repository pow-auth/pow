defmodule Pow.Phoenix.SessionControllerTest do
  use Pow.Test.Phoenix.ConnCase
  alias Pow.{Phoenix.Messages, Plug}

  @user_signed_in_message Messages.signed_in(nil)
  @invalid_credentials_message Messages.invalid_credentials(nil)
  @user_signed_out_message Messages.signed_out(nil)

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
      assert html =~ "<label for=\"user_email\">Email</label>"
      assert html =~ "<input id=\"user_email\" name=\"user[email]\" type=\"text\">"
      assert html =~ "<label for=\"user_password\">Password</label>"
      assert html =~ "<input id=\"user_password\" name=\"user[password]\" type=\"password\">"
      refute html =~ "request_url"
    end

    test "with request_url", %{conn: conn} do
      conn = get(conn, Routes.pow_session_path(conn, :new, request_url: "/example"))

      assert html = html_response(conn, 200)
      assert html =~ "?request_url=%2Fexample"
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
      assert get_flash(conn, :info) == @user_signed_in_message
      assert %{id: 1} = Plug.current_user(conn)
      assert conn.private[:plug_session]["auth"]
    end

    test "with invalid params", %{conn: conn} do
      conn = post conn, Routes.pow_session_path(conn, :create, @invalid_params)
      assert html = html_response(conn, 200)
      assert get_flash(conn, :error) == @invalid_credentials_message
      assert html =~ "<input id=\"user_email\" name=\"user[email]\" type=\"text\" value=\"test@example.com\">"
      assert html =~ "<input id=\"user_password\" name=\"user[password]\" type=\"password\">"
      refute Plug.current_user(conn)
      refute conn.private[:plug_session]["auth"]
      refute html =~ "request_url"
    end

    test "with valid params and request_url", %{conn: conn} do
      conn = post conn, Routes.pow_session_path(conn, :create, Map.put(@valid_params, "request_url", "/custom-url"))
      assert redirected_to(conn) == "/custom-url"
      assert get_flash(conn, :info) == @user_signed_in_message
      assert %{id: 1} = Plug.current_user(conn)
      assert conn.private[:plug_session]["auth"]
    end

    test "with invalid params and request_url", %{conn: conn} do
      conn = post conn, Routes.pow_session_path(conn, :create, Map.put(@invalid_params, "request_url", "/custom-url"))
      assert html = html_response(conn, 200)
      assert get_flash(conn, :error) == @invalid_credentials_message
      assert html =~ "?request_url=%2Fcustom-url"
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
      assert get_flash(conn, :info) == @user_signed_out_message
      refute Plug.current_user(conn)
      refute conn.private[:plug_session]["auth"]
    end
  end
end
