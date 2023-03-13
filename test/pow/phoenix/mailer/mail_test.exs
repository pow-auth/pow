defmodule Pow.Phoenix.TestMail do
  @moduledoc false
  use Pow.Phoenix.Mailer.Template

  template :test,
  "Test subject",
  """
  <%= @value %> text
  """,
  """
  <h3><%= @value %> HTML</h3>
  """
end

defmodule Pow.Phoenix.Mailer.MailTest do
  use ExUnit.Case
  doctest Pow.Phoenix.Mailer.Mail

  alias Plug.Conn
  alias Pow.Phoenix.{Mailer.Mail, TestMail}

  setup do
    {:ok, conn: %Conn{private: %{pow_config: []}}}
  end

  test "new/4", %{conn: conn} do
    assert mail = Mail.new(conn, :user, {TestMail, :test}, value: "test")

    assert mail.user == :user
    assert mail.subject == "Test subject"
    assert mail.html =~ "<h3>test HTML</h3>"
    assert mail.text =~ "test text\n"
    assert mail.assigns[:value] == "test"
  end

  test "new/4 with `:web_module`", %{conn: conn} do
    conn = Conn.put_private(conn, :pow_config, web_mailer_module: Pow.Test.Phoenix)
    assert mail = Mail.new(conn, :user, {TestMail, :test}, value: "test")

    assert mail.user == :user
    assert mail.subject == ":web_mailer_module subject :user"
    assert mail.html == "<p>:web_mailer_module html mail :user</p>"
    assert mail.text == ":web_mailer_module text mail :user"
  end

  test "new/4 with `:pow_mailer_layouts` setting", %{conn: conn} do
    conn = Conn.put_private(conn, :pow_mailer_layouts, html: {Pow.Test.Phoenix.Layouts, :email}, text: {Pow.Test.Phoenix.Layouts, :email_text})
    assert mail = Mail.new(conn, :user, {TestMail, :test}, value: "test")

    assert mail.user == :user
    assert mail.html =~ "<h1>Pow e-mail</h1>"
    assert mail.text =~ "Pow e-mail\n"
  end

  test "new/4 with invalid `:pow_mailer_layouts` value", %{conn: conn} do
    conn = Conn.put_private(conn, :pow_mailer_layouts, :invalid)
    assert mail = Mail.new(conn, :user, {TestMail, :test}, value: "test")

    refute mail.html =~ "<h1>Pow e-mail</h1>"
    refute mail.text =~ "Pow e-mail"
  end
end
