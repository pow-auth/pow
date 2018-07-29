defmodule PowResetPassword.Phoenix.ResetPasswordControllerTest do
  use PowResetPassword.TestWeb.Phoenix.ConnCase

  alias Pow.Test.EtsCacheMock
  alias PowResetPassword.Store.ResetTokenCache
  alias PowResetPassword.Test.Users.User

  @user %User{id: 1}
  @password "secret1234"

  describe "new/2" do
    test "shows", %{conn: conn} do
      conn = get(conn, Routes.pow_reset_password_reset_password_path(conn, :new))

      assert html = html_response(conn, 200)
      assert html =~ "<label for=\"user_email\">Email</label>"
      assert html =~ "<input id=\"user_email\" name=\"user[email]\" type=\"text\">"
    end

    test "already signed in", %{conn: conn} do
      conn =
        conn
        |> Pow.Plug.assign_current_user(@user, [])
        |> get(Routes.pow_reset_password_reset_password_path(conn, :new))

      assert_authenticated_redirect(conn)
    end
  end

  describe "create/2" do
    @valid_params %{"user" => %{"email" => "test@example.com"}}
    @invalid_params %{"user" => %{"email" => "invalid@example.com"}}

    test "already signed in", %{conn: conn} do
      conn =
        conn
        |> Pow.Plug.assign_current_user(@user, [])
        |> get(Routes.pow_reset_password_reset_password_path(conn, :new))

      assert_authenticated_redirect(conn)
    end

    test "with valid params", %{conn: conn} do
      conn  = post conn, Routes.pow_reset_password_reset_password_path(conn, :create, @valid_params)
      token = conn.private[:reset_password_token]

      assert_received {:mail_mock, mail}

      assert mail.subject == "Reset password link"
      assert mail.text =~ "\nhttp://localhost/reset-password/#{token}/edit\n"
      assert mail.html =~ "<a href=\"http://localhost/reset-password/#{token}/edit\">"

      assert redirected_to(conn) == Routes.pow_session_path(conn, :new)
      assert get_flash(conn, :info) == "An email with reset instructions has been sent to you. Please check your inbox."
    end

    test "with invalid params", %{conn: conn} do
      conn = post conn, Routes.pow_reset_password_reset_password_path(conn, :create, @invalid_params)
      assert redirected_to(conn) == Routes.pow_session_path(conn, :new)
      assert get_flash(conn, :info) == "An email with reset instructions has been sent to you. Please check your inbox."
    end
  end

  describe "edit/2" do
    @valid_token "valid"
    @invalid_token "invalid"

    setup %{conn: conn} do
      ResetTokenCache.put([backend: EtsCacheMock], @valid_token, @user)

      {:ok, conn: conn}
    end

    test "already signed in", %{conn: conn} do
      conn =
        conn
        |> Pow.Plug.assign_current_user(@user, [])
        |> get(Routes.pow_reset_password_reset_password_path(conn, :edit, @valid_token))

      assert_authenticated_redirect(conn)
    end

    test "invalid token", %{conn: conn} do
      conn = get conn, Routes.pow_reset_password_reset_password_path(conn, :edit, @invalid_token)

      assert redirected_to(conn) == Routes.pow_reset_password_reset_password_path(conn, :new)
      assert get_flash(conn, :error) == "The reset token has expired."
    end

    test "valid token", %{conn: conn} do
      conn = get conn, Routes.pow_reset_password_reset_password_path(conn, :edit, @valid_token)

      assert html = html_response(conn, 200)
      assert html =~ "<label for=\"user_password\">Password</label>"
      assert html =~ "<input id=\"user_password\" name=\"user[password]\" type=\"password\">"
      assert html =~ "<label for=\"user_confirm_password\">Confirm password</label>"
      assert html =~ "<input id=\"user_confirm_password\" name=\"user[confirm_password]\" type=\"password\">"
    end
  end

  describe "update/2" do
    @valid_token "valid"
    @invalid_token "invalid"

    @valid_params %{"user" => %{"password" => @password, "confirm_password" => @password}}
    @invalid_params %{"user" => %{"password" => @password, "confirm_password" => "invalid"}}

    setup %{conn: conn} do
      ResetTokenCache.put([backend: EtsCacheMock], @valid_token, @user)

      {:ok, conn: conn}
    end

    test "already signed in", %{conn: conn} do
      conn =
        conn
        |> Pow.Plug.assign_current_user(@user, [])
        |> put(Routes.pow_reset_password_reset_password_path(conn, :update, @valid_token, @valid_params))

      assert_authenticated_redirect(conn)
    end

    test "invalid token", %{conn: conn} do
      conn = put conn, Routes.pow_reset_password_reset_password_path(conn, :update, @invalid_token, @valid_params)

      assert redirected_to(conn) == Routes.pow_reset_password_reset_password_path(conn, :new)
      assert get_flash(conn, :error) == "The reset token has expired."
    end

    test "with valid params", %{conn: conn} do
      conn = put conn, Routes.pow_reset_password_reset_password_path(conn, :update, @valid_token, @valid_params)

      assert redirected_to(conn) == Routes.pow_session_path(conn, :new)
      assert get_flash(conn, :info) == "The password has been updated."

      assert ResetTokenCache.get([backend: EtsCacheMock], @valid_token) == :not_found
    end

    test "with invalid params", %{conn: conn} do
      conn = put conn, Routes.pow_reset_password_reset_password_path(conn, :update, @valid_token, @invalid_params)

      assert html = html_response(conn, 200)
      assert html =~ "<label for=\"user_password\">Password</label>"
      assert html =~ "<input id=\"user_password\" name=\"user[password]\" type=\"password\">"
      assert html =~ "<span class=\"help-block\">not same as password</span>"
      assert errors = conn.assigns[:changeset].errors
      assert errors[:confirm_password]

      assert ResetTokenCache.get([backend: EtsCacheMock], @valid_token) == @user
    end
  end
end
