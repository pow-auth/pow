defmodule PowEmailConfirmation.Phoenix.ConfirmationControllerTest do
  use PowEmailConfirmation.TestWeb.Phoenix.ConnCase

  describe "show/2" do
    test "confirms with valid token", %{conn: conn} do
      conn = get conn, Routes.pow_email_confirmation_confirmation_path(conn, :show, "valid")

      assert redirected_to(conn) == Routes.pow_registration_path(conn, :edit)
      assert get_flash(conn, :info) == "The email address has been confirmed."

      assert user = Process.get({:user, 1})
      assert user.email == "test@example.com"
      assert user.email_confirmed_at
      refute user.unconfirmed_email
    end

    test "confirms with valid token and :unconfirmed_email", %{conn: conn} do
      conn = get conn, Routes.pow_email_confirmation_confirmation_path(conn, :show, "valid_unconfirmed_email")
      assert redirected_to(conn) == Routes.pow_registration_path(conn, :edit)
      assert get_flash(conn, :info) == "The email address has been confirmed."

      assert user = Process.get({:user, 1})
      assert user.email == "new@example.com"
      assert user.email_confirmed_at
      refute user.unconfirmed_email
    end

    test "fails with invalid token", %{conn: conn} do
      conn = get conn, Routes.pow_email_confirmation_confirmation_path(conn, :show, "invalid")

      assert redirected_to(conn) == Routes.pow_registration_path(conn, :edit)
      assert get_flash(conn, :error) == "The email address couldn't be confirmed."

      refute Process.get({:user, 1})
    end
  end
end
