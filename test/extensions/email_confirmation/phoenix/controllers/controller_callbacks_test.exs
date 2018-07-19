defmodule AuthexEmailConfirmation.Phoenix.ControllerCallbacksTest do
  use AuthexEmailConfirmation.Test.Phoenix.ConnCase
  alias Authex.Plug
  alias AuthexEmailConfirmation.Test.Users.User

  describe "Authex.Phoenix.RegistrationController.create/2" do
    @valid_params %{"user" => %{"email" => "test@example.com", "password" => "secret", "confirm_password" => "secret"}}

    test "with valid params", %{conn: conn} do
      conn = post conn, Routes.authex_registration_path(conn, :create, @valid_params)
      assert get_flash(conn, :info) == "User has been created successfully."
      assert %{id: 1, email_confirmation_token: token} = Plug.current_user(conn)

      assert_received {:mail_mock, mail}
      mail.html =~ "/reset-password/#{token}"
    end
  end

  describe "Authex.Phoenix.RegistrationController.update/2" do
    @email_change_params %{"user" => %{"email" => "new@example.com", "current_password" => "secret"}}
    @params %{"user" => %{"email" => "test@example.com", "current_password" => "secret"}}

    setup %{conn: conn} do
      user = %User{id: 1, email: "test@example.com", password_hash: Comeonin.Pbkdf2.hashpwsalt("secret"), email_confirmation_token: "token"}
      conn = Plug.assign_current_user(conn, user, [])

      {:ok, conn: conn}
    end

    test "with email change", %{conn: conn} do
      conn = put conn, Routes.authex_registration_path(conn, :update, @email_change_params)
      assert get_flash(conn, :info) == "User has been updated successfully."
      assert %{id: 1, email_confirmation_token: token} = Plug.current_user(conn)
      assert token != "token"

      assert_received {:mail_mock, mail}
      mail.html =~ "/reset-password/#{token}"
    end

    test "without email change", %{conn: conn} do
      conn = put conn, Routes.authex_registration_path(conn, :update, @params)
      assert get_flash(conn, :info) == "User has been updated successfully."
      assert %{id: 1, email_confirmation_token: "token"} = Plug.current_user(conn)

      refute_received {:mail_mock, _mail}
    end
  end
end
