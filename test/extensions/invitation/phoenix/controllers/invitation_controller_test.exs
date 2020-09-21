defmodule PowInvitation.Phoenix.InvitationControllerTest do
  use PowInvitation.TestWeb.Phoenix.ConnCase

  alias Plug.Conn
  alias Pow.Plug, as: PowPlug
  alias PowInvitation.Plug
  alias PowInvitation.{Test, Test.Users.User, Test.Users.UsernameUser}

  @user %User{id: 1, email: "test@example.com"}
  @url_regex ~r/http:\/\/localhost\/invitations\/[a-zA-Z0-9\-\_\.]*\/edit/

  describe "new/2" do
    test "not signed in", %{conn: conn} do
      conn = get(conn, Routes.pow_invitation_invitation_path(conn, :new))

      assert_not_authenticated_redirect(conn)
    end

    test "shows", %{conn: conn} do
      conn =
        conn
        |> Pow.Plug.assign_current_user(@user, [])
        |> get(Routes.pow_invitation_invitation_path(conn, :new))

      assert html = html_response(conn, 200)
      assert html =~ "<label for=\"user_email\">Email</label>"
      assert html =~ "<input id=\"user_email\" name=\"user[email]\" type=\"text\">"
    end

    test "shows with username user", %{conn: conn} do
      conn =
        conn
        |> Conn.put_private(:pow_test_config, user: UsernameUser)
        |> Pow.Plug.assign_current_user(@user, [])
        |> get(Routes.pow_invitation_invitation_path(conn, :new))

      assert html = html_response(conn, 200)
      assert html =~ "<label for=\"user_username\">Username</label>"
      assert html =~ "<input id=\"user_username\" name=\"user[username]\" type=\"text\">"
    end
  end

  describe "create/2" do
    @valid_params %{"user" => %{"email" => "test@example.com"}}
    @invalid_params %{"user" => %{"email" => "invalid"}}
    @valid_params_email_taken %{"user" => %{"email" => "taken@example.com"}}
    @valid_params_no_email %{"user" => %{"email" => :no_email}}

    test "not signed in", %{conn: conn} do
      conn = post(conn, Routes.pow_invitation_invitation_path(conn, :create, @valid_params))

      assert_not_authenticated_redirect(conn)
    end

    test "with valid params", %{conn: conn} do
      conn =
        conn
        |> Pow.Plug.assign_current_user(@user, [])
        |> post(Routes.pow_invitation_invitation_path(conn, :create, @valid_params))

      assert_received {:mail_mock, mail}

      assert mail.subject == "You've been invited"
      assert mail.text =~ "You've been invited by #{@user.email}."
      assert mail.text =~ @url_regex
      assert mail.html =~ "<p>You&#39;ve been invited by #{@user.email}."
      assert mail.html =~ @url_regex

      assert redirected_to(conn) == Routes.pow_invitation_invitation_path(conn, :new)
      assert get_flash(conn, :info) == "An e-mail with invitation link has been sent."
    end

    test "with invalid params", %{conn: conn} do
      conn =
        conn
        |> Pow.Plug.assign_current_user(@user, [])
        |> post(Routes.pow_invitation_invitation_path(conn, :create, @invalid_params))

      assert html = html_response(conn, 200)
      assert html =~ "<label for=\"user_email\">Email</label>"
      assert html =~ "<input id=\"user_email\" name=\"user[email]\" type=\"text\" value=\"invalid\">"
      assert html =~ "<span class=\"help-block\">has invalid format</span>"
    end

    test "with valid params and email taken", %{conn: conn} do
      conn =
        conn
        |> Pow.Plug.assign_current_user(@user, [])
        |> post(Routes.pow_invitation_invitation_path(conn, :create, @valid_params_email_taken))

      refute_received {:mail_mock, _mail}

      assert redirected_to(conn) == Routes.pow_invitation_invitation_path(conn, :new)
      assert get_flash(conn, :info) == "An e-mail with invitation link has been sent."
    end

    test "with valid params and email taken with pow_prevent_user_enumeration: false", %{conn: conn} do
      conn =
        conn
        |> Conn.put_private(:pow_prevent_user_enumeration, false)
        |> Pow.Plug.assign_current_user(@user, [])
        |> post(Routes.pow_invitation_invitation_path(conn, :create, @valid_params_email_taken))

      assert html = html_response(conn, 200)
      assert html =~ "<label for=\"user_email\">Email</label>"
      assert html =~ "<input id=\"user_email\" name=\"user[email]\" type=\"text\" value=\"taken@example.com\">"
      assert html =~ "<span class=\"help-block\">has already been taken</span>"
    end

    test "user with no email", %{conn: conn} do
      conn =
        conn
        |> Pow.Plug.assign_current_user(@user, [])
        |> post(Routes.pow_invitation_invitation_path(conn, :create, @valid_params_no_email))

      refute_received {:mail_mock, _mail}

      assert redirected_to(conn) == Routes.pow_invitation_invitation_path(conn, :show, sign_token("valid"))
    end
  end

  describe "show/2" do
    test "not signed in", %{conn: conn} do
      conn = get(conn, Routes.pow_invitation_invitation_path(conn, :show, sign_token("valid")))

      assert_not_authenticated_redirect(conn)
    end

    test "shows", %{conn: conn} do
      conn =
        conn
        |> Pow.Plug.assign_current_user(@user, [])
        |> get(Routes.pow_invitation_invitation_path(conn, :show, sign_token("valid")))

      assert html = html_response(conn, 200)
      assert html =~ @url_regex
    end
  end

  describe "edit/2" do
    test "already signed in", %{conn: conn} do
      conn =
        conn
        |> Pow.Plug.assign_current_user(@user, [])
        |> get(Routes.pow_invitation_invitation_path(conn, :edit, sign_token("valid")))

      assert_authenticated_redirect(conn)
    end

    test "with invalid invitation token", %{conn: conn} do
      conn = get(conn, Routes.pow_invitation_invitation_path(conn, :edit, sign_token("invalid")))

      assert redirected_to(conn) == Routes.pow_session_path(conn, :new)
      assert get_flash(conn, :error) == "The invitation doesn't exist."
    end

    test "with unsigned invitation token", %{conn: conn} do
      conn = get(conn, Routes.pow_invitation_invitation_path(conn, :edit, "valid"))

      assert redirected_to(conn) == Routes.pow_session_path(conn, :new)
      assert get_flash(conn, :error) == "The invitation doesn't exist."
    end

    test "shows", %{conn: conn} do
      conn = get(conn, Routes.pow_invitation_invitation_path(conn, :edit, sign_token("valid")))

      assert Conn.get_resp_header(conn, "cache-control") == ["no-cache, no-store, must-revalidate"]

      assert html = html_response(conn, 200)
      assert html =~ "<label for=\"user_email\">Email</label>"
      assert html =~ "<input id=\"user_email\" name=\"user[email]\" type=\"text\" value=\"test@example.com\">"
      assert html =~ "<label for=\"user_password\">Password</label>"
      assert html =~ "<input id=\"user_password\" name=\"user[password]\" type=\"password\">"
      assert html =~ "<label for=\"user_password_confirmation\">Password confirmation</label>"
      assert html =~ "<input id=\"user_password_confirmation\" name=\"user[password_confirmation]\" type=\"password\">"
      assert html =~ "<button type=\"submit\">Submit</button>"
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
        |> put(Routes.pow_invitation_invitation_path(conn, :update, sign_token("valid"), @valid_params))

      assert_authenticated_redirect(conn)
    end

    test "with invalid invitation", %{conn: conn} do
      conn = put(conn, Routes.pow_invitation_invitation_path(conn, :update, sign_token("invalid"), @valid_params))

      assert redirected_to(conn) == Routes.pow_session_path(conn, :new)
      assert get_flash(conn, :error) == "The invitation doesn't exist."
    end

    test "with unsigned invitation token", %{conn: conn} do
      conn = put(conn, Routes.pow_invitation_invitation_path(conn, :update, "valid", @valid_params))

      assert redirected_to(conn) == Routes.pow_session_path(conn, :new)
      assert get_flash(conn, :error) == "The invitation doesn't exist."
    end

    test "with valid params", %{conn: conn} do
      conn = put(conn, Routes.pow_invitation_invitation_path(conn, :update, sign_token("valid"), @valid_params))

      assert redirected_to(conn) == "/after_registration"
      assert get_flash(conn, :info) == "user_created"
      assert conn.private[:plug_session]["auth"]
    end

    test "with valid params and email taken", %{conn: conn} do
      conn = put(conn, Routes.pow_invitation_invitation_path(conn, :update, sign_token("valid"), @valid_params_email_taken))

      assert html = html_response(conn, 200)
      assert html =~ "<label for=\"user_email\">Email</label>"
      assert html =~ "<input id=\"user_email\" name=\"user[email]\" type=\"text\" value=\"taken@example.com\">"
      assert html =~ "<span class=\"help-block\">has already been taken</span>"
    end

    test "with invalid params", %{conn: conn} do
      conn = put(conn, Routes.pow_invitation_invitation_path(conn, :update, sign_token("valid"), @invalid_params))

      assert html = html_response(conn, 200)
      assert html =~ "<label for=\"user_email\">Email</label>"
      assert html =~ "<input id=\"user_email\" name=\"user[email]\" type=\"text\" value=\"invalid\">"
      assert html =~ "<span class=\"help-block\">has invalid format</span>"
      assert html =~ "<label for=\"user_password\">Password</label>"
      assert html =~ "<input id=\"user_password\" name=\"user[password]\" type=\"password\">"
      assert html =~ "<span class=\"help-block\">does not match confirmation</span>"
      refute conn.private[:plug_session]["auth"]
    end
  end

  defp sign_token(token) do
    %Conn{}
    |> PowPlug.put_config(Test.pow_config())
    |> Plug.sign_invitation_token(%{invitation_token: token})
  end
end
