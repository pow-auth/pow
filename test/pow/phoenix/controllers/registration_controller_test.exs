defmodule Pow.Phoenix.RegistrationControllerTest do
  use Pow.Test.Phoenix.ConnCase
  alias Pow.Plug

  describe "new/2" do
    test "shows", %{conn: conn} do
      conn = get(conn, Routes.pow_registration_path(conn, :new))

      assert html = html_response(conn, 200)
      assert html =~ Routes.pow_registration_path(conn, :create)
      assert html =~ "<label for=\"user_email\">Email</label>"
      assert html =~ "<input id=\"user_email\" name=\"user[email]\" type=\"text\">"
      assert html =~ "<label for=\"user_password\">Password</label>"
      assert html =~ "<input id=\"user_password\" name=\"user[password]\" type=\"password\">"
      assert html =~ "<label for=\"user_confirm_password\">Confirm password</label>"
      assert html =~ "<input id=\"user_confirm_password\" name=\"user[confirm_password]\" type=\"password\">"
      assert html =~ "<a href=\"/session/new\">Sign in</a>"
    end

    test "already signed in", %{conn: conn} do
      conn =
        conn
        |> Plug.assign_current_user(%{id: 1}, [])
        |> get(Routes.pow_registration_path(conn, :new))

      assert_authenticated_redirect(conn)
    end
  end

  describe "create/2" do
    @valid_params %{"user" => %{"email" => "test@example.com", "password" => "secret"}}
    @invalid_params %{"user" => %{"email" => "test@example.com", "password" => "s"}}

    test "already signed in", %{conn: conn} do
      conn =
        conn
        |> Plug.assign_current_user(%{id: 1}, [])
        |> post(Routes.pow_registration_path(conn, :create, @valid_params))

      assert_authenticated_redirect(conn)
    end

    test "with valid params", %{conn: conn} do
      conn = post conn, Routes.pow_registration_path(conn, :create, @valid_params)
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) == "user_created"
      assert %{id: 1} = Plug.current_user(conn)
      assert conn.private[:plug_session]["auth"]
    end

    test "with invalid params", %{conn: conn} do
      conn = post conn, Routes.pow_registration_path(conn, :create, @invalid_params)
      assert html = html_response(conn, 200)
      assert html =~ "<input id=\"user_email\" name=\"user[email]\" type=\"text\" value=\"test@example.com\">"
      assert html =~ "<label for=\"user_password\">Password</label>"
      assert html =~ "<input id=\"user_password\" name=\"user[password]\" type=\"password\">"
      assert html =~ "<span class=\"help-block\">should be at least 10 character(s)</span>"
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
        |> get(Routes.pow_registration_path(conn, :edit))

      assert html = html_response(conn, 200)
      assert html =~ "<label for=\"user_email\">Email</label>"
      assert html =~ "<input id=\"user_email\" name=\"user[email]\" type=\"text\" value=\"test@example.com\">"
      assert html =~ "<label for=\"user_current_password\">Current password</label>"
      assert html =~ "<input id=\"user_current_password\" name=\"user[current_password]\" type=\"password\">"
    end

    test "not signed in", %{conn: conn} do
      conn = get(conn, Routes.pow_registration_path(conn, :edit))

      assert_not_authenticated_redirect(conn)
    end
  end

  describe "update/2" do
    @valid_params %{"user" => %{"email" => "test@example.com", "password" => "secret"}}
    @invalid_params %{"user" => %{"email" => "test@example.com"}}

    test "not signed in", %{conn: conn} do
      conn = put(conn, Routes.pow_registration_path(conn, :update, @valid_params))

      assert_not_authenticated_redirect(conn)
    end

    test "with valid params", %{conn: conn} do
      conn = create_user_and_sign_in(conn)
      session_id = conn.private[:plug_session]["auth"]

      conn = put(conn, Routes.pow_registration_path(conn, :update, @valid_params))

      assert redirected_to(conn) == Routes.pow_registration_path(conn, :edit)
      assert get_flash(conn, :info) == "Your account has been updated."
      assert user = Plug.current_user(conn)
      assert user.id == :updated
      assert conn.private[:plug_session]["auth"] != session_id
    end

    test "with invalid params", %{conn: conn} do
      conn = create_user_and_sign_in(conn)
      session_id = conn.private[:plug_session]["auth"]

      conn = put(conn, Routes.pow_registration_path(conn, :update, @invalid_params))

      assert html = html_response(conn, 200)
      assert html =~ "<label for=\"user_email\">Email</label>"
      assert html =~ "<input id=\"user_email\" name=\"user[email]\" type=\"text\" value=\"test@example.com\">"
      assert html =~ "<label for=\"user_current_password\">Current password</label>"
      assert html =~ "<input id=\"user_current_password\" name=\"user[current_password]\" type=\"password\">"
      assert html =~ "<span class=\"help-block\">can&#39;t be blank</span>"
      assert errors = conn.assigns[:changeset].errors
      assert errors[:current_password]
      assert %{id: 1} = Plug.current_user(conn)
      assert conn.private[:plug_session]["auth"] == session_id
    end
  end

  describe "delete/2" do
    test "not signed in", %{conn: conn} do
      conn = delete(conn, Routes.pow_registration_path(conn, :delete))

      assert_not_authenticated_redirect(conn)
    end

    test "deletes and removes authenticated", %{conn: conn} do
      conn =
        conn
        |> create_user_and_sign_in()
        |> delete(Routes.pow_registration_path(conn, :delete))

      assert redirected_to(conn) == Routes.pow_session_path(conn, :new)
      assert get_flash(conn, :info) == "Your account has been deleted. Sorry to see you go!"
      refute Plug.current_user(conn)
      refute conn.private[:plug_session]["auth"]
    end

    test "when fails", %{conn: conn} do
      conn =
        conn
        |> Plug.assign_current_user(:fail_deletion, [])
        |> delete(Routes.pow_registration_path(conn, :delete))

      assert redirected_to(conn) == Routes.pow_registration_path(conn, :edit)
      assert get_flash(conn, :error) == "Your account could not be deleted."
      assert Plug.current_user(conn) == :fail_deletion
    end
  end

  defp create_user_and_sign_in(conn) do
    conn = post conn, Routes.pow_registration_path(conn, :create, @valid_params)
    assert %{id: 1} = Plug.current_user(conn)
    assert conn.private[:plug_session]["auth"]
    :timer.sleep(10)

    conn
  end
end
