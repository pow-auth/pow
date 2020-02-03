defmodule Pow.Phoenix.MailerTest.Mailer do
  use Pow.Phoenix.Mailer

  def cast(email), do: {:cast, email}

  def process({:cast, email}), do: {:process, email}
end

defmodule Pow.Phoenix.MailerTest do
  use Pow.Test.Phoenix.ConnCase
  doctest Pow.Phoenix.Mailer

  alias Pow.Phoenix.Mailer
  alias Pow.Test.Phoenix.Pow.MailerView

  setup %{conn: conn} do
    email =
      conn
      |> Plug.Conn.put_private(:pow_config, [])
      |> Mailer.Mail.new(%{email: "test@example.com"}, {MailerView, :mail_test}, value: "test")

    {:ok, email: email}
  end

  test "deliver/2", %{conn: conn, email: email} do
    assert_raise Pow.Config.ConfigError, "Pow configuration not found in connection. Please use a Pow plug that puts the Pow configuration in the plug connection.", fn ->
      Mailer.deliver(conn, email)
    end

    res =
      conn
      |> Plug.Conn.put_private(:pow_config, mailer_backend: Pow.Phoenix.MailerTest.Mailer)
      |> Mailer.deliver(email)

    assert res == {:process, email}
  end
end
