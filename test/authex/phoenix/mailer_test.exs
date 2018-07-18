defmodule Authex.Phoenix.MailerTest.Mailer do
  use Authex.Phoenix.Mailer

  def cast(email), do: {:cast, email}
  def process({:cast, email}), do: {:process, email}
end

defmodule Authex.Phoenix.MailerTest do
  use Authex.Test.Phoenix.ConnCase
  doctest Authex.Phoenix.Mailer

  alias Authex.Phoenix.Mailer

  setup %{conn: conn} do
    email = Mailer.Mail.new(%{email: "test@example.com"}, :text, :html, :subject)

    {:ok, conn: conn, email: email}
  end


  test "Mail.new/3", %{email: email} do
    assert email == %Authex.Phoenix.Mailer.Mail{user: %{email: "test@example.com"}, text: :text, html: :html, subject: :subject}
  end

  test "deliver/2", %{conn: conn, email: email} do
    assert_raise Authex.Config.ConfigError, "Authex configuration not found. Please set the Authex.Plug.Session plug beforehand.", fn ->
      Mailer.deliver(conn, email)
    end

    res =
      conn
      |> Plug.Conn.put_private(:authex_config, [mailer: Authex.Phoenix.MailerTest.Mailer])
      |> Mailer.deliver(email)

    assert res == {:process, email}
  end
end
