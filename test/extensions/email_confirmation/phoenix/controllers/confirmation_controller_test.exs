defmodule PowEmailConfirmation.Phoenix.ConfirmationControllerTest do
  use PowEmailConfirmation.TestWeb.Phoenix.ConnCase

  alias Plug.Conn
  alias Pow.Plug, as: PowPlug
  alias PowEmailConfirmation.Plug
  alias PowEmailConfirmation.{Test, Test.Users.User}

  @session_key "auth"

  describe "show/2" do
    test "confirms with valid token", %{conn: conn} do
      conn = get(conn, Routes.pow_email_confirmation_confirmation_path(conn, :show, sign_token("valid")))

      assert redirected_to(conn) == Routes.pow_session_path(conn, :new)
      assert get_flash(conn, :info) == "The email address has been confirmed."

      assert user = Process.get({:user, 1})
      assert user.email == "test@example.com"
      assert user.email_confirmed_at
      refute user.unconfirmed_email
      refute Pow.Plug.current_user(conn)
    end

    test "confirms with valid token and :unconfirmed_email", %{conn: conn} do
      conn = get(conn, Routes.pow_email_confirmation_confirmation_path(conn, :show, sign_token("valid-with-unconfirmed-changed-email")))

      assert redirected_to(conn) == Routes.pow_session_path(conn, :new)
      assert get_flash(conn, :info) == "The email address has been confirmed."

      assert user = Process.get({:user, 1})
      assert user.email == "new@example.com"
      assert user.email_confirmed_at
      refute user.unconfirmed_email
    end

    test "fails with unique constraint", %{conn: conn} do
      conn = get(conn, Routes.pow_email_confirmation_confirmation_path(conn, :show, sign_token("valid-with-taken-email")))

      assert redirected_to(conn) == Routes.pow_session_path(conn, :new)
      assert get_flash(conn, :error) == "The email address couldn't be confirmed."

      refute Process.get({:user, 1})
    end

    test "fails with invalid token", %{conn: conn} do
      conn = get(conn, Routes.pow_email_confirmation_confirmation_path(conn, :show, sign_token("invalid")))

      assert redirected_to(conn) == Routes.pow_session_path(conn, :new)
      assert get_flash(conn, :error) == "The confirmation token is invalid or has expired."

      refute Process.get({:user, 1})
    end

    test "fails with unsigned token", %{conn: conn} do
      conn = get(conn, Routes.pow_email_confirmation_confirmation_path(conn, :show, "valid"))

      assert redirected_to(conn) == Routes.pow_session_path(conn, :new)
      assert get_flash(conn, :error) == "The confirmation token is invalid or has expired."

      refute Process.get({:user, 1})
    end

    test "when the same user is signed in", %{conn: conn} do
      session_id = conn.private[:plug_session][@session_key]
      conn       =
        conn
        |> Pow.Plug.assign_current_user(%User{id: 1}, [])
        |> get(Routes.pow_email_confirmation_confirmation_path(conn, :show, sign_token("valid")))

      assert redirected_to(conn) == Routes.pow_registration_path(conn, :edit)
      assert Pow.Plug.current_user(conn)
      refute conn.private[:plug_session][@session_key] == session_id
    end

    test "when the signed in user is different", %{conn: conn} do
      session_id = conn.private[:plug_session][@session_key]
      conn       =
        conn
        |> Pow.Plug.assign_current_user(%User{id: 2}, [])
        |> get(Routes.pow_email_confirmation_confirmation_path(conn, :show, sign_token("valid")))

      assert redirected_to(conn) == Routes.pow_registration_path(conn, :edit)
      assert Pow.Plug.current_user(conn)
      assert conn.private[:plug_session][@session_key] == session_id
    end
  end

  defp sign_token(token) do
    %Conn{}
    |> PowPlug.put_config(Test.pow_config())
    |> Plug.sign_confirmation_token(%{email_confirmation_token: token})
  end
end
