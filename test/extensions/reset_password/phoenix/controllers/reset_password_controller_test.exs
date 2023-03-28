defmodule PowResetPassword.Phoenix.ResetPasswordControllerTest do
  use PowResetPassword.TestWeb.Phoenix.ConnCase

  alias Phoenix.LiveViewTest.DOM
  alias Plug.Conn
  alias Pow.Plug, as: PowPlug
  alias PowResetPassword.{Plug, Store.ResetTokenCache}
  alias PowResetPassword.{Test, Test.Users.User}

  @user %User{id: 1}
  @password "secret1234"

  describe "new/2" do
    test "shows", %{conn: conn} do
      conn = get(conn, ~p"/reset-password/new")

      assert html = html_response(conn, 200)

      html_tree = DOM.parse(html)

      assert [label_elem] = DOM.all(html_tree, "label[for=user_email]")
      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[email]\"]")
      assert DOM.to_text(label_elem) =~ "Email"
      assert DOM.attribute(input_elem, "type") == "email"
      refute DOM.attribute(input_elem, "value")
      assert DOM.attribute(input_elem, "required")
    end

    test "already signed in", %{conn: conn} do
      conn =
        conn
        |> PowPlug.assign_current_user(@user, [])
        |> get(~p"/reset-password/new")

      assert_authenticated_redirect(conn)
    end
  end

  describe "create/2" do
    @valid_params %{"user" => %{"email" => "test@example.com"}}
    @invalid_params %{"user" => %{"email" => "invalid@example.com"}}

    test "already signed in", %{conn: conn} do
      conn =
        conn
        |> PowPlug.assign_current_user(@user, [])
        |> get(~p"/reset-password/new")

      assert_authenticated_redirect(conn)
    end

    test "with valid params", %{conn: conn, ets: ets} do
      conn           = post(conn, ~p"/reset-password", @valid_params)
      [{[token], _}] = ResetTokenCache.all([backend: ets], [:_])

      assert_received {:mail_mock, mail}

      assert mail.subject == "Reset password link"
      assert mail.text =~ "\nhttp://localhost/reset-password/#{sign_token(conn, token)}\n"
      assert mail.html =~ "<a href=\"http://localhost/reset-password/#{sign_token(conn, token)}\">"

      assert redirected_to(conn) == ~p"/session/new"
      assert get_flash(conn, :info) == "If an account for the provided email exists, an email with reset instructions will be sent to you. Please check your inbox."
    end

    test "with invalid params", %{conn: conn} do
      conn = post(conn, ~p"/reset-password", @invalid_params)

      assert redirected_to(conn) == ~p"/session/new"
      assert get_flash(conn, :info) == "If an account for the provided email exists, an email with reset instructions will be sent to you. Please check your inbox."
    end

    test "with invalid params and pow_prevent_user_enumeration: false", %{conn: conn} do
      conn =
        conn
        |> Conn.put_private(:pow_prevent_user_enumeration, false)
        |> post(~p"/reset-password", @invalid_params)

      assert html = html_response(conn, 200)
      assert get_flash(conn, :error) == "No account exists for the provided email. Please try again."

      html_tree = DOM.parse(html)

      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[email]\"]")
      assert DOM.attribute(input_elem, "value") == "invalid@example.com"
    end
  end

  describe "edit/2" do
    setup %{conn: conn} do
      token = create_reset_token(conn, "test@example.com")

      {:ok, conn: conn, token: token}
    end

    test "already signed in", %{conn: conn, token: token} do
      conn =
        conn
        |> PowPlug.assign_current_user(@user, [])
        |> get(~p"/reset-password/#{token}")

      assert_authenticated_redirect(conn)
    end

    test "with invalid token", %{conn: conn} do
      conn = get(conn, ~p"/reset-password/invalid")

      assert redirected_to(conn) == ~p"/reset-password/new"
      assert get_flash(conn, :error) == "The reset token has expired."
    end

    test "with unsigned token", %{conn: conn, token: token} do
      token = decode_token(conn, token)
      conn  = get(conn, ~p"/reset-password/#{token}")

      assert redirected_to(conn) == ~p"/reset-password/new"
      assert get_flash(conn, :error) == "The reset token has expired."
    end

    test "valid token", %{conn: conn, token: token} do
      conn = get(conn, ~p"/reset-password/#{token}")

      assert html = html_response(conn, 200)

      html_tree = DOM.parse(html)

      assert [label_elem] = DOM.all(html_tree, "label[for=user_password]")
      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[password]\"]")
      assert DOM.to_text(label_elem) =~ "New password"
      assert DOM.attribute(input_elem, "type") == "password"
      assert DOM.attribute(input_elem, "required")

      assert [label_elem] = DOM.all(html_tree, "label[for=user_password_confirmation]")
      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[password_confirmation]\"]")
      assert DOM.to_text(label_elem) =~ "Confirm new password"
      assert DOM.attribute(input_elem, "type") == "password"
      assert DOM.attribute(input_elem, "required")

      assert [_] = DOM.all(html, "a[href=\"/session/new\"]")
    end
  end

  describe "update/2" do
    @valid_params %{"user" => %{"password" => @password, "password_confirmation" => @password}}
    @invalid_params %{"user" => %{"password" => @password, "password_confirmation" => "invalid"}}

    setup %{conn: conn} do
      token = create_reset_token(conn, "test@example.com")

      {:ok, conn: conn, token: token}
    end

    test "already signed in", %{conn: conn, token: token} do
      conn =
        conn
        |> PowPlug.assign_current_user(@user, [])
        |> put(~p"/reset-password/#{token}", @valid_params)

      assert_authenticated_redirect(conn)
    end

    test "with invalid token", %{conn: conn} do
      conn = put(conn, ~p"/reset-password/invalid", @valid_params)

      assert redirected_to(conn) == ~p"/reset-password/new"
      assert get_flash(conn, :error) == "The reset token has expired."
    end

    test "with unsigned token", %{conn: conn, token: token} do
      token = decode_token(conn, token)
      conn  = put(conn, ~p"/reset-password/#{token}", @valid_params)

      assert redirected_to(conn) == ~p"/reset-password/new"
      assert get_flash(conn, :error) == "The reset token has expired."
    end

    test "with valid params", %{conn: conn, token: token} do
      conn = put(conn, ~p"/reset-password/#{token}", @valid_params)

      assert redirected_to(conn) == ~p"/session/new"
      assert get_flash(conn, :info) == "The password has been updated."

      assert {:error, _conn} = Plug.load_user_by_token(conn, token)
    end

    test "with invalid params", %{conn: conn, token: token} do
      conn = put(conn, ~p"/reset-password/#{token}", @invalid_params)

      assert html = html_response(conn, 200)

      html_tree = DOM.parse(html)

      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[password]\"]")
      assert DOM.attribute(input_elem, "value") == @password

      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[password_confirmation]\"]")
      assert [error_elem] = DOM.all(html_tree, "*[phx-feedback-for=\"user[password_confirmation]\"] > p")
      assert DOM.attribute(input_elem, "value") == "invalid"
      assert DOM.to_text(error_elem) =~ "does not match confirmation"

      changeset = conn.assigns[:changeset]
      assert changeset.errors[:password_confirmation]
      assert changeset.action == :update

      assert {:ok, _conn} = Plug.load_user_by_token(conn, token)
    end
  end

  defp create_reset_token(conn, email) do
    {:ok, %{token: token}, _conn} =
      conn
      |> PowPlug.put_config(Test.pow_config())
      |> Plug.create_reset_token(%{"email" => email})

    token
  end

  defp decode_token(conn, token) do
    {:ok, token} =
      conn
      |> PowPlug.put_config(Test.pow_config())
      |> PowPlug.verify_token(Atom.to_string(Plug), token)

    token
  end

  defp sign_token(conn, token), do: PowPlug.sign_token(conn, Atom.to_string(Plug), token)
end
