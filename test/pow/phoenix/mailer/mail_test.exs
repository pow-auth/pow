defmodule Pow.Phoenix.MailerTemplate do
  @moduledoc false
  use Pow.Phoenix.Mailer.Template

  template :mail_test,
  "Test subject",
  """
  <%= @value %> text
  """,
  """
  <%= content_tag(:h3, "\#{@value} HTML") %>
  """
end

defmodule Pow.Phoenix.MailerView do
  @moduledoc false
  use Pow.Phoenix.Mailer.View
end

defmodule Pow.Phoenix.Mailer.MailTest do
  use ExUnit.Case
  doctest Pow.Phoenix.Mailer.Mail

  alias Plug.Conn
  alias Pow.Phoenix.{Mailer.Mail, MailerView}

  setup do
    {:ok, conn: %Conn{private: %{pow_config: []}}}
  end

  test "new/4", %{conn: conn} do
    assert mail = Mail.new(conn, :user, {MailerView, :mail_test}, value: "test")

    assert mail.user == :user
    assert mail.subject == "Test subject"
    assert mail.html =~ "<h3>test HTML</h3>"
    assert mail.text =~ "test text\n"
    assert mail.assigns[:value] == "test"
    assert mail.conn == conn
  end

  test "new/4 with `:web_module`", %{conn: conn} do
    conn = Conn.put_private(conn, :pow_config, web_mailer_module: Pow.Test.Phoenix)
    assert mail = Mail.new(conn, :user, {MailerView, :mail_test}, value: "test")

    assert mail.user == :user
    assert mail.subject == ":web_mailer_module subject :user"
    assert mail.html == "<p>:web_mailer_module html mail :user</p>"
    assert mail.text == ":web_mailer_module text mail :user"
  end

  test "new/4 with `:pow_mailer_layout` setting", %{conn: conn} do
    conn = Conn.put_private(conn, :pow_mailer_layout, {Pow.Test.Phoenix.LayoutView, :email})
    assert mail = Mail.new(conn, :user, {MailerView, :mail_test}, value: "test")

    assert mail.user == :user
    assert mail.html =~ "<h1>Pow e-mail</h1>"
    assert mail.text =~ "Pow e-mail\n"
  end

  test "new/4 with `:pow_mailer_layout` html only setting", %{conn: conn} do
    conn = Conn.put_private(conn, :pow_mailer_layout, {Pow.Test.Phoenix.LayoutView, "email.html"})
    assert mail = Mail.new(conn, :user, {MailerView, :mail_test}, value: "test")

    assert mail.user == :user
    assert mail.html =~ "<h1>Pow e-mail</h1>"
    refute mail.text =~ "Pow e-mail\n"
  end
end
