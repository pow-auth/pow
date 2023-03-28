defmodule Pow.Phoenix.SessionControllerTest do
  use Pow.Test.Phoenix.ConnCase

  alias Plug.Conn
  alias Phoenix.LiveViewTest.DOM
  alias Pow.Plug

  describe "new/2" do
    test "already signed in", %{conn: conn} do
      conn =
        conn
        |> Plug.assign_current_user(%{id: 1}, [])
        |> get(~p"/session/new")

      assert_authenticated_redirect(conn)
    end

    test "shows", %{conn: conn} do
      conn = get(conn, ~p"/session/new")

      assert Conn.get_resp_header(conn, "cache-control") == ["no-cache, no-store, must-revalidate"]

      assert html = html_response(conn, 200)
      assert html =~ ~p"/session"
      refute html =~ "request_path="

      html_tree = DOM.parse(html)

      assert [label_elem] = DOM.all(html_tree, "label[for=user_email]")
      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[email]\"]")
      assert DOM.to_text(label_elem) =~ "Email"
      assert DOM.attribute(input_elem, "type") == "email"
      refute DOM.attribute(input_elem, "value")
      assert DOM.attribute(input_elem, "required")

      assert [label_elem] = DOM.all(html_tree, "label[for=user_password]")
      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[password]\"]")
      assert DOM.to_text(label_elem) =~ "Password"
      assert DOM.attribute(input_elem, "type") == "password"
      refute DOM.attribute(input_elem, "value")
      assert DOM.attribute(input_elem, "required")

      assert [_] = DOM.all(html, "a[href=\"/registration/new\"]")
    end

    test "with request_path", %{conn: conn} do
      conn = get(conn, ~p"/session/new?#{[request_path: "/example"]}")

      assert html = html_response(conn, 200)
      assert html =~ ~p"/session?#{[request_path: "/example"]}"
    end

    test "shows with username user", %{conn: conn} do
      conn =
        conn
        |> Conn.put_private(:pow_test_config, :username_user)
        |> get(~p"/session/new")

      assert html = html_response(conn, 200)

      html_tree = DOM.parse(html)

      assert [label_elem] = DOM.all(html_tree, "label[for=user_username]")
      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[username]\"]")
      assert DOM.to_text(label_elem) =~ "Username"
      assert DOM.attribute(input_elem, "type") == "text"
    end
  end

  describe "create/2" do
    @valid_params %{"user" => %{"email" => "mock@example.com", "password" => "secret"}}
    @invalid_params %{"user" => %{"email" => "invalid@example.com", "password" => "invalid"}}

    test "already signed in", %{conn: conn} do
      conn =
        conn
        |> Plug.assign_current_user(%{id: 1}, [])
        |> post(~p"/session", @valid_params)

      assert_authenticated_redirect(conn)
    end

    test "with valid params", %{conn: conn} do
      conn = post(conn, ~p"/session", @valid_params)

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) == "signed_in"
      assert %{id: 1} = Plug.current_user(conn)
      assert conn.private[:plug_session]["auth"]
    end

    test "with invalid params", %{conn: conn} do
      conn = post(conn, ~p"/session", @invalid_params)

      assert html = html_response(conn, 200)
      assert get_flash(conn, :error) == "The provided login details did not work. Please verify your credentials, and try again."

      html_tree = DOM.parse(html)

      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[email]\"]")
      assert DOM.attribute(input_elem, "value") == "invalid@example.com"

      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[password]\"]")
      refute DOM.attribute(input_elem, "value")

      refute Plug.current_user(conn)
      refute conn.private[:plug_session]["auth"]
      refute html =~ "request_path"
    end

    test "with valid params and request_path", %{conn: conn} do
      conn = post(conn, ~p"/session", Map.put(@valid_params, "request_path", "/custom-url"))

      assert redirected_to(conn) == "/custom-url"
      assert get_flash(conn, :info) == "signed_in"
      assert %{id: 1} = Plug.current_user(conn)
      assert conn.private[:plug_session]["auth"]
    end

    test "with invalid params and request_path", %{conn: conn} do
      conn = post(conn, ~p"/session", Map.put(@invalid_params, "request_path", "/custom-url"))

      assert html = html_response(conn, 200)
      assert get_flash(conn, :error) == "The provided login details did not work. Please verify your credentials, and try again."
      assert html =~ "?request_path=%2Fcustom-url"
    end
  end

  describe "delete/2" do
    test "not signed in", %{conn: conn} do
      conn = delete(conn, ~p"/session")

      assert_not_authenticated_redirect(conn)
    end

    test "removes authenticated", %{conn: conn} do
      conn = authenticated_conn(conn)

      conn = delete(conn, ~p"/session")
      assert redirected_to(conn) == "/signed_out"
      assert get_flash(conn, :info) == "signed_out"
      refute Plug.current_user(conn)
      refute conn.private[:plug_session]["auth"]
    end
  end

  @auth_params %{"user" => %{"email" => "mock@example.com", "password" => "secret"}}

  defp authenticated_conn(conn) do
    conn = post(conn, ~p"/session", @auth_params)

    assert %{id: 1} = Plug.current_user(conn)
    assert conn.private[:plug_session]["auth"]
    assert_receive {:ets, :put, [{_key, _value} | _rest], _opts}

    conn
  end
end
