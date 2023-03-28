defmodule PowInvitation.Phoenix.InvitationControllerTest do
  use PowInvitation.TestWeb.Phoenix.ConnCase

  alias Phoenix.LiveViewTest.DOM
  alias Plug.Conn
  alias Pow.Plug, as: PowPlug
  alias PowInvitation.Plug
  alias PowInvitation.{Test, Test.Users.User, Test.Users.UsernameUser}

  @user %User{id: 1, email: "test@example.com"}
  @url_regex ~r/http:\/\/localhost\/invitations\/[a-zA-Z0-9\-\_\.]*\/edit/

  describe "new/2" do
    test "not signed in", %{conn: conn} do
      conn = get(conn, ~p"/invitations/new")

      assert_not_authenticated_redirect(conn)
    end

    test "shows", %{conn: conn} do
      conn =
        conn
        |> Pow.Plug.assign_current_user(@user, [])
        |> get(~p"/invitations/new")

      assert html = html_response(conn, 200)

      html_tree = DOM.parse(html)

      assert [label_elem] = DOM.all(html_tree, "label[for=user_email]")
      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[email]\"]")
      assert DOM.to_text(label_elem) =~ "Email"
      assert DOM.attribute(input_elem, "type") == "email"
      refute DOM.attribute(input_elem, "value")
      assert DOM.attribute(input_elem, "required")
    end

    test "shows with username user", %{conn: conn} do
      conn =
        conn
        |> Conn.put_private(:pow_test_config, user: UsernameUser)
        |> Pow.Plug.assign_current_user(@user, [])
        |> get(~p"/invitations/new")

      assert html = html_response(conn, 200)

      html_tree = DOM.parse(html)

      assert [label_elem] = DOM.all(html_tree, "label[for=user_username]")
      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[username]\"]")
      assert DOM.to_text(label_elem) =~ "Username"
      assert DOM.attribute(input_elem, "type") == "text"
    end
  end

  describe "create/2" do
    @valid_params %{"user" => %{"email" => "test@example.com"}}
    @invalid_params %{"user" => %{"email" => "invalid"}}
    @valid_params_email_taken %{"user" => %{"email" => "taken@example.com"}}
    @valid_params_no_email %{"user" => %{"email" => "no_email"}}

    test "not signed in", %{conn: conn} do
      conn = post(conn, ~p"/invitations", @valid_params)

      assert_not_authenticated_redirect(conn)
    end

    test "with valid params", %{conn: conn} do
      conn =
        conn
        |> Pow.Plug.assign_current_user(@user, [])
        |> post(~p"/invitations", @valid_params)

      assert_received {:mail_mock, mail}

      assert mail.subject == "You've been invited"
      assert mail.text =~ "You've been invited by #{@user.email}."
      assert mail.text =~ @url_regex
      assert mail.html =~ "<p>You've been invited by <strong>#{@user.email}</strong>."
      assert mail.html =~ @url_regex

      assert redirected_to(conn) == ~p"/invitations/new"
      assert get_flash(conn, :info) == "An e-mail with invitation link has been sent."
    end

    test "with invalid params", %{conn: conn} do
      conn =
        conn
        |> Pow.Plug.assign_current_user(@user, [])
        |> post(~p"/invitations", @invalid_params)

      assert html = html_response(conn, 200)

      html_tree = DOM.parse(html)

      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[email]\"]")
      assert [error_elem] = DOM.all(html_tree, "*[phx-feedback-for=\"user[email]\"] > p")
      assert DOM.attribute(input_elem, "value") == "invalid"
      assert DOM.to_text(error_elem) =~ "has invalid format"
    end

    test "with valid params and email taken", %{conn: conn} do
      conn =
        conn
        |> Pow.Plug.assign_current_user(@user, [])
        |> post(~p"/invitations", @valid_params_email_taken)

      refute_received {:mail_mock, _mail}

      assert redirected_to(conn) == ~p"/invitations/new"
      assert get_flash(conn, :info) == "An e-mail with invitation link has been sent."
    end

    test "with valid params and email taken with pow_prevent_user_enumeration: false", %{conn: conn} do
      conn =
        conn
        |> Conn.put_private(:pow_prevent_user_enumeration, false)
        |> Pow.Plug.assign_current_user(@user, [])
        |> post(~p"/invitations", @valid_params_email_taken)

      assert html = html_response(conn, 200)

      html_tree = DOM.parse(html)

      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[email]\"]")
      assert [error_elem] = DOM.all(html_tree, "*[phx-feedback-for=\"user[email]\"] > p")
      assert DOM.attribute(input_elem, "value") == "taken@example.com"
      assert DOM.to_text(error_elem) =~ "has already been taken"
    end

    test "user with no email", %{conn: conn} do
      conn =
        conn
        |> Pow.Plug.assign_current_user(@user, [])
        |> post(~p"/invitations", @valid_params_no_email)

      refute_received {:mail_mock, _mail}

      assert redirected_to(conn) == ~p"/invitations/#{sign_token("valid")}"
    end
  end

  describe "show/2" do
    test "not signed in", %{conn: conn} do
      conn = get(conn, ~p"/invitations/#{sign_token("valid")}")

      assert_not_authenticated_redirect(conn)
    end

    test "shows", %{conn: conn} do
      conn =
        conn
        |> Pow.Plug.assign_current_user(@user, [])
        |> get(~p"/invitations/#{sign_token("valid")}")

      assert html = html_response(conn, 200)
      assert html =~ @url_regex
    end
  end

  describe "edit/2" do
    test "already signed in", %{conn: conn} do
      conn =
        conn
        |> Pow.Plug.assign_current_user(@user, [])
        |> get(~p"/invitations/#{sign_token("valid")}/edit")

      assert_authenticated_redirect(conn)
    end

    test "with invalid invitation token", %{conn: conn} do
      conn = get(conn, ~p"/invitations/#{sign_token("invalid")}/edit")

      assert redirected_to(conn) == ~p"/session/new"
      assert get_flash(conn, :error) == "The invitation doesn't exist."
    end

    test "with unsigned invitation token", %{conn: conn} do
      conn = get(conn, ~p"/invitations/#{"valid"}/edit")

      assert redirected_to(conn) == ~p"/session/new"
      assert get_flash(conn, :error) == "The invitation doesn't exist."
    end

    test "shows", %{conn: conn} do
      conn = get(conn, ~p"/invitations/#{sign_token("valid")}/edit")

      assert Conn.get_resp_header(conn, "cache-control") == ["no-cache, no-store, must-revalidate"]

      assert html = html_response(conn, 200)

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
    end
  end

  describe "update/2" do
    @password "password1234"
    @valid_params %{"user" => %{"email" => "test@example.com", "password" => @password, "password_confirmation" => @password}}
    @valid_params_email_taken %{"user" => %{"email" => "taken@example.com", "password" => @password, "password_confirmation" => @password}}
    @invalid_params %{"user" => %{"email" => "invalid", "password" => @password, "password_confirmation" => "invalid"}}

    test "already signed in", %{conn: conn} do
      conn =
        conn
        |> Pow.Plug.assign_current_user(@user, [])
        |> put(~p"/invitations/#{sign_token("valid")}", @valid_params)

      assert_authenticated_redirect(conn)
    end

    test "with invalid invitation", %{conn: conn} do
      conn = put(conn, ~p"/invitations/#{sign_token("invalid")}", @valid_params)

      assert redirected_to(conn) == ~p"/session/new"
      assert get_flash(conn, :error) == "The invitation doesn't exist."
    end

    test "with unsigned invitation token", %{conn: conn} do
      conn = put(conn, ~p"/invitations/#{"valid"}", @valid_params)

      assert redirected_to(conn) == ~p"/session/new"
      assert get_flash(conn, :error) == "The invitation doesn't exist."
    end

    test "with valid params", %{conn: conn} do
      conn = put(conn, ~p"/invitations/#{sign_token("valid")}", @valid_params)

      assert redirected_to(conn) == "/after_registration"
      assert get_flash(conn, :info) == "user_created"
      assert conn.private[:plug_session]["auth"]
    end

    test "with valid params and email taken", %{conn: conn} do
      conn = put(conn, ~p"/invitations/#{sign_token("valid")}", @valid_params_email_taken)

      assert html = html_response(conn, 200)

      html_tree = DOM.parse(html)

      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[email]\"]")
      assert [error_elem] = DOM.all(html_tree, "*[phx-feedback-for=\"user[email]\"] > p")
      assert DOM.attribute(input_elem, "value") == "taken@example.com"
      assert DOM.to_text(error_elem) =~ "has already been taken"
    end

    test "with invalid params", %{conn: conn} do
      conn = put(conn, ~p"/invitations/#{sign_token("valid")}", @invalid_params)

      assert html = html_response(conn, 200)

      html_tree = DOM.parse(html)

      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[email]\"]")
      assert [error_elem] = DOM.all(html_tree, "*[phx-feedback-for=\"user[email]\"] > p")
      assert DOM.attribute(input_elem, "value") == "invalid"
      assert DOM.to_text(error_elem) =~ "has invalid format"

      assert [input_elem] = DOM.all(html_tree, "input[name=\"user[password_confirmation]\"]")
      assert [error_elem] = DOM.all(html_tree, "*[phx-feedback-for=\"user[password_confirmation]\"] > p")
      assert DOM.attribute(input_elem, "value") == "invalid"
      assert DOM.to_text(error_elem) =~ "does not match confirmation"

      refute conn.private[:plug_session]["auth"]
    end
  end

  defp sign_token(token) do
    %Conn{}
    |> PowPlug.put_config(Test.pow_config())
    |> Plug.sign_invitation_token(%{invitation_token: token})
  end
end
