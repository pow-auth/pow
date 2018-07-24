defmodule PowEmailConfirmation.Phoenix.ConfirmationControllerTest do
  use PowEmailConfirmation.TestWeb.Phoenix.ConnCase

  describe "show/2" do
    @valid_token "valid"
    @invalid_params "invalid"

    test "confirms with valid token", %{conn: conn} do
      conn = get conn, Routes.pow_email_confirmation_confirmation_path(conn, :show, @valid_token)
      assert redirected_to(conn) == Routes.pow_registration_path(conn, :edit)
      assert get_flash(conn, :info) == "The email address has been confirmed."
    end

    test "fails with invalid token", %{conn: conn} do
      conn = get conn, Routes.pow_email_confirmation_confirmation_path(conn, :show, @invalid_params)
      assert redirected_to(conn) == Routes.pow_registration_path(conn, :edit)
      assert get_flash(conn, :error) == "The email address couldn't be confirmed."
    end
  end
end
