defmodule PowEmailConfirmation.Phoenix.ControllerCallbacksTest do
  use PowEmailConfirmation.Test.Phoenix.ConnCase
  alias Pow.{Phoenix.Messages, Plug}
  alias PowEmailConfirmation.Test.Users.User

  @user_created_message Messages.user_has_been_created(nil)
  @user_updated_message Messages.user_has_been_updated(nil)

  describe "Pow.Phoenix.RegistrationController.create/2" do
    @valid_params %{"user" => %{"email" => "test@example.com", "password" => "secret", "confirm_password" => "secret"}}

    test "with valid params", %{conn: conn} do
      conn = post conn, Routes.pow_registration_path(conn, :create, @valid_params)
      assert get_flash(conn, :info) == @user_created_message
      assert %{id: 1, email_confirmation_token: token} = Plug.current_user(conn)

      assert_received {:mail_mock, mail}
      mail.html =~ "/reset-password/#{token}"
    end
  end

  describe "Pow.Phoenix.RegistrationController.update/2" do
    @email_change_params %{"user" => %{"email" => "new@example.com", "current_password" => "secret"}}
    @params %{"user" => %{"email" => "test@example.com", "current_password" => "secret"}}

    setup %{conn: conn} do
      user = %User{id: 1, email: "test@example.com", password_hash: Comeonin.Pbkdf2.hashpwsalt("secret"), email_confirmation_token: "token"}
      conn = Plug.assign_current_user(conn, user, [])

      {:ok, conn: conn}
    end

    test "with email change", %{conn: conn} do
      conn = put conn, Routes.pow_registration_path(conn, :update, @email_change_params)
      assert get_flash(conn, :info) == @user_updated_message
      assert %{id: 1, email_confirmation_token: token} = Plug.current_user(conn)
      assert token != "token"

      assert_received {:mail_mock, mail}
      mail.html =~ "/reset-password/#{token}"
    end

    test "without email change", %{conn: conn} do
      conn = put conn, Routes.pow_registration_path(conn, :update, @params)
      assert get_flash(conn, :info) == @user_updated_message
      assert %{id: 1, email_confirmation_token: "token"} = Plug.current_user(conn)

      refute_received {:mail_mock, _mail}
    end
  end
end
