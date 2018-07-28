defmodule Pow.Phoenix.MailerTest.Mailer do
  use Pow.Phoenix.Mailer

  def cast(email), do: {:cast, email}
  def process({:cast, email}), do: {:process, email}
end

defmodule Pow.Phoenix.MailerTest do
  use Pow.Test.Phoenix.ConnCase
  doctest Pow.Phoenix.Mailer

  alias Pow.Phoenix.Mailer

  setup %{conn: conn} do
    email = Mailer.Mail.new(%{email: "test@example.com"}, :text, :html, :subject)

    {:ok, conn: conn, email: email}
  end

  test "Mail.new/3", %{email: email} do
    assert email == %Pow.Phoenix.Mailer.Mail{user: %{email: "test@example.com"}, text: :text, html: :html, subject: :subject}
  end

  test "deliver/2", %{conn: conn, email: email} do
    assert_raise Pow.Config.ConfigError, "Pow configuration not found. Please set the Pow.Plug.Session plug beforehand.", fn ->
      Mailer.deliver(conn, email)
    end

    res =
      conn
      |> Plug.Conn.put_private(:pow_config, [mailer_backend: Pow.Phoenix.MailerTest.Mailer])
      |> Mailer.deliver(email)

    assert res == {:process, email}
  end
end
