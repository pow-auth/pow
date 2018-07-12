defmodule Authex.Phoenix.RegistrationControllerTest do
  use Authex.Test.Phoenix.ConnCase
  alias Authex.Plug

  describe "new/2" do
    test "shows", %{conn: conn} do
      conn = get(conn, Routes.authex_registration_path(conn, :new))

      assert html = html_response(conn, 200)
      assert html =~ "New registration"
    end

    test "already signed in", %{conn: conn} do
      conn =
        conn
        |> Plug.assign_current_user(%{id: 1}, [])
        |> get(Routes.authex_registration_path(conn, :new))

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) == "You're already authenticated."
    end
  end

  describe "create/2" do
    @valid_params %{"user" => %{"email" => "test@example.com", "password" => "secret"}}
    @invalid_params %{"user" => %{"email" => "test@example.com"}}

    test "already signed in", %{conn: conn} do
      conn =
        conn
        |> Plug.assign_current_user(%{id: 1}, [])
        |> post(Routes.authex_registration_path(conn, :create, @valid_params))

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) == "You're already authenticated."
    end

    test "with valid params", %{conn: conn} do
      conn = post conn, Routes.authex_registration_path(conn, :create, @valid_params)
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) == "User has been created successfully."
      assert Plug.current_user(conn) == %{id: 1}
      assert conn.private[:plug_session]["auth"]
    end

    test "with invalid params", %{conn: conn} do
      conn = post conn, Routes.authex_registration_path(conn, :create, @invalid_params)
      assert html = html_response(conn, 200)
      assert html =~ "New registration"
      assert conn.assigns[:changeset] == @invalid_params["user"]
      refute Plug.current_user(conn)
      refute conn.private[:plug_session]["auth"]
    end
  end

  describe "show/2" do
    test "shows", %{conn: conn} do
      conn =
        conn
        |> create_user_and_sign_in()
        |> get(Routes.authex_registration_path(conn, :show))

      assert html = html_response(conn, 200)
      assert html =~ "Show registration %{id: 1}"
    end

    test "not signed in", %{conn: conn} do
      conn = get(conn, Routes.authex_registration_path(conn, :show))

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) == "You're not authenticated."
    end
  end

  describe "edit/2" do
    test "shows", %{conn: conn} do
      conn =
        conn
        |> create_user_and_sign_in()
        |> get(Routes.authex_registration_path(conn, :edit))

      assert html = html_response(conn, 200)
      assert html =~ "Edit registration %{id: 1}"
    end

    test "not signed in", %{conn: conn} do
      conn = get(conn, Routes.authex_registration_path(conn, :edit))

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) == "You're not authenticated."
    end
  end

  describe "update/2" do
    @valid_params %{"user" => %{"email" => "test@example.com", "password" => "secret"}}
    @invalid_params %{"user" => %{"email" => "test@example.com"}}

    test "not signed in", %{conn: conn} do
      conn = put(conn, Routes.authex_registration_path(conn, :update, @valid_params))

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) == "You're not authenticated."
    end

    test "with valid params", %{conn: conn} do
      conn = create_user_and_sign_in(conn)
      session_id = conn.private[:plug_session]["auth"]

      conn = put(conn, Routes.authex_registration_path(conn, :update, @valid_params))

      assert redirected_to(conn) == Routes.authex_registration_path(conn, :show)
      assert get_flash(conn, :info) == "User has been updated successfully."
      assert Plug.current_user(conn) == %{id: 1, updated: true}
      assert conn.private[:plug_session]["auth"] != session_id
    end

    test "with invalid params", %{conn: conn} do
      conn = create_user_and_sign_in(conn)
      session_id = conn.private[:plug_session]["auth"]

      conn = put(conn, Routes.authex_registration_path(conn, :update, @invalid_params))

      assert html = html_response(conn, 200)
      assert html =~ "Edit registration"
      assert conn.assigns[:changeset] == @invalid_params["user"]
      assert Plug.current_user(conn) == %{id: 1}
      assert conn.private[:plug_session]["auth"] == session_id
    end
  end

  describe "delete/2" do
    test "not signed in", %{conn: conn} do
      conn = delete(conn, Routes.authex_registration_path(conn, :delete))

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) == "You're not authenticated."
    end

    test "deletes and removes authenticated", %{conn: conn} do
      conn =
        conn
        |> create_user_and_sign_in()
        |> delete(Routes.authex_registration_path(conn, :delete))

      assert redirected_to(conn) == Routes.authex_session_path(conn, :new)
      assert get_flash(conn, :info) == "User has been deleted successfully."
      refute Plug.current_user(conn)
      refute conn.private[:plug_session]["auth"]
    end

    test "when fails", %{conn: conn} do
      conn =
        conn
        |> Plug.assign_current_user(:fail_deletion, [])
        |> delete(Routes.authex_registration_path(conn, :delete))

      assert html = html_response(conn, 200)
      assert html =~ "Edit registration :fail_deletion"
      assert Plug.current_user(conn) == :fail_deletion
    end
  end

  defp create_user_and_sign_in(conn) do
    conn = post conn, Routes.authex_registration_path(conn, :create, @valid_params)
    assert Plug.current_user(conn) == %{id: 1}
    assert conn.private[:plug_session]["auth"]

    conn
  end
end
