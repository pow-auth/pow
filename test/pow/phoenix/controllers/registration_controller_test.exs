defmodule Pow.Phoenix.RegistrationControllerTest do
  use Pow.Test.Phoenix.ConnCase

  alias Plug.Conn
  alias Phoenix.LiveViewTest.DOM
  alias Pow.Plug

  describe "new/2" do
    test "shows", %{conn: conn} do
      conn = get(conn, ~p"/registration/new")

      assert Conn.get_resp_header(conn, "cache-control") == ["no-cache, no-store, must-revalidate"]

      assert html = html_response(conn, 200)
      assert html =~ ~p"/registration"

      html_tree = DOM.parse(html)

      assert [label_elem] = DOM.all(html_tree, "label[for=user_email]")
      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[email]\"]")
      assert DOM.to_text(label_elem) =~ "Email"
      assert DOM.attribute(input_elem, "type") == "email"
      assert DOM.attribute(input_elem, "required")

      assert [label_elem] = DOM.all(html_tree, "label[for=user_password]")
      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[password]\"]")
      assert DOM.to_text(label_elem) =~ "Password"
      assert DOM.attribute(input_elem, "type") == "password"
      assert DOM.attribute(input_elem, "required")

      assert [label_elem] = DOM.all(html_tree, "label[for=user_password_confirmation]")
      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[password_confirmation]\"]")
      assert DOM.to_text(label_elem) =~ "Confirm password"
      assert DOM.attribute(input_elem, "type") == "password"
      assert DOM.attribute(input_elem, "required")

      assert [_] = DOM.all(html, "a[href=\"/session/new\"]")
    end

    test "already signed in", %{conn: conn} do
      conn =
        conn
        |> Plug.assign_current_user(%{id: 1}, [])
        |> get(~p"/registration/new")

      assert_authenticated_redirect(conn)
    end

    test "shows with username user", %{conn: conn} do
      conn =
        conn
        |> Conn.put_private(:pow_test_config, :username_user)
        |> get(~p"/registration/new")

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
        |> post(~p"/registration", @valid_params)

      assert_authenticated_redirect(conn)
    end

    test "with valid params", %{conn: conn} do
      conn = post(conn, ~p"/registration", @valid_params)

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) == "user_created"
      assert %{id: 1} = Plug.current_user(conn)
      assert conn.private[:plug_session]["auth"]
    end

    test "with invalid params", %{conn: conn} do
      conn = post(conn, ~p"/registration", @invalid_params)

      assert html = html_response(conn, 200)

      html_tree = DOM.parse(html)

      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[email]\"]")
      assert DOM.attribute(input_elem, "value") == "invalid@example.com"

      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[password]\"]")
      assert [error_elem] = DOM.all(html_tree, "*[phx-feedback-for=\"user[password]\"] > p")
      assert DOM.attribute(input_elem, "value") == "invalid"
      assert DOM.to_text(error_elem) =~ "should be at least 8 character(s)"

      assert errors = conn.assigns[:changeset].errors
      assert errors[:password]
      refute Plug.current_user(conn)
      refute conn.private[:plug_session]["auth"]
    end
  end

  describe "edit/2" do
    test "shows", %{conn: conn} do
      conn =
        conn
        |> create_user_and_sign_in()
        |> get(~p"/registration/edit")

      assert html = html_response(conn, 200)

      html_tree = DOM.parse(html)

      assert [label_elem] = DOM.all(html_tree, "label[for=user_current_password]")
      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[current_password]\"]")
      assert DOM.to_text(label_elem) =~ "Current password"
      assert DOM.attribute(input_elem, "type") == "password"
      assert DOM.attribute(input_elem, "required")

      assert [label_elem] = DOM.all(html_tree, "label[for=user_email]")
      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[email]\"]")
      assert DOM.to_text(label_elem) =~ "Email"
      assert DOM.attribute(input_elem, "type") == "email"
      assert DOM.attribute(input_elem, "value") == "mock@example.com"
      assert DOM.attribute(input_elem, "required")

      assert [label_elem] = DOM.all(html_tree, "label[for=user_password]")
      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[password]\"]")
      assert DOM.to_text(label_elem) =~ "New password"
      assert DOM.attribute(input_elem, "type") == "password"
      refute DOM.attribute(input_elem, "value")
      refute DOM.attribute(input_elem, "required")

      assert [label_elem] = DOM.all(html_tree, "label[for=user_password_confirmation]")
      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[password_confirmation]\"]")
      assert DOM.to_text(label_elem) =~ "Confirm new password"
      assert DOM.attribute(input_elem, "type") == "password"
      refute DOM.attribute(input_elem, "value")
      refute DOM.attribute(input_elem, "required")
    end

    test "shows with username user", %{conn: conn} do
      conn =
        conn
        |> Conn.put_private(:pow_test_config, :username_user)
        |> create_user_and_sign_in()
        |> get(~p"/registration/edit")

      assert html = html_response(conn, 200)

      html_tree = DOM.parse(html)

      assert [label_elem] = DOM.all(html_tree, "label[for=user_username]")
      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[username]\"]")
      assert DOM.to_text(label_elem) =~ "Username"
      assert DOM.attribute(input_elem, "type") == "text"
      assert DOM.attribute(input_elem, "value") == "test"
    end

    test "not signed in", %{conn: conn} do
      conn = get(conn, ~p"/registration/edit")

      assert_not_authenticated_redirect(conn)
    end
  end

  describe "update/2" do
    @valid_params %{"user" => %{"email" => "mock@example.com", "password" => "secret"}}
    @invalid_params %{"user" => %{"email" => "invalid@example.com", "password" => "invalid"}}

    test "not signed in", %{conn: conn} do
      conn = put(conn, ~p"/registration", @valid_params)

      assert_not_authenticated_redirect(conn)
    end

    test "with valid params", %{conn: conn} do
      conn = create_user_and_sign_in(conn)
      session_id = conn.private[:plug_session]["auth"]

      conn = put(conn, ~p"/registration", @valid_params)

      assert redirected_to(conn) == ~p"/registration/edit"
      assert get_flash(conn, :info) == "Your account has been updated."
      assert user = Plug.current_user(conn)
      assert user.id == :updated
      assert conn.private[:plug_session]["auth"] != session_id
    end

    test "with invalid params", %{conn: conn} do
      conn = create_user_and_sign_in(conn)
      session_id = conn.private[:plug_session]["auth"]

      conn = put(conn, ~p"/registration", @invalid_params)

      assert html = html_response(conn, 200)

      html_tree = DOM.parse(html)

      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[current_password]\"]")
      assert [error_elem] = DOM.all(html_tree, "*[phx-feedback-for=\"user[current_password]\"] > p")
      refute DOM.attribute(input_elem, "value")
      assert DOM.to_text(error_elem) =~ "can't be blank"

      assert [label_elem] = DOM.all(html_tree, "label[for=user_email]")
      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[email]\"]")
      assert DOM.to_text(label_elem) =~ "Email"
      assert DOM.attribute(input_elem, "type") == "email"
      assert DOM.attribute(input_elem, "value") == "invalid@example.com"

      assert errors = conn.assigns[:changeset].errors
      assert errors[:current_password]
      assert %{id: 1} = Plug.current_user(conn)
      assert conn.private[:plug_session]["auth"] == session_id
    end
  end

  describe "delete/2" do
    test "not signed in", %{conn: conn} do
      conn = delete(conn, ~p"/registration")

      assert_not_authenticated_redirect(conn)
    end

    test "deletes and removes authenticated", %{conn: conn} do
      conn =
        conn
        |> create_user_and_sign_in()
        |> delete(~p"/registration")

      assert redirected_to(conn) == "/signed_out"
      assert get_flash(conn, :info) == "Your account has been deleted. Sorry to see you go!"
      refute Plug.current_user(conn)
      refute conn.private[:plug_session]["auth"]
    end

    test "when fails", %{conn: conn} do
      conn =
        conn
        |> Plug.assign_current_user(:fail_deletion, [])
        |> delete(~p"/registration")

      assert redirected_to(conn) == ~p"/registration/edit"
      assert get_flash(conn, :error) == "Your account could not be deleted."
      assert Plug.current_user(conn) == :fail_deletion
    end
  end

  @params %{"user" => %{"email" => "mock@example.com"}}

  defp create_user_and_sign_in(conn) do
    conn = post(conn, ~p"/registration", @params)

    assert %{id: 1} = Plug.current_user(conn)
    assert conn.private[:plug_session]["auth"]
    assert_receive {:ets, :put, [{_key, _value} | _rest], _opts}

    conn
  end
end
